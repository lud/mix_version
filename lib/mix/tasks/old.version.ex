defmodule Mix.Tasks.Old.Version do
  alias MixVersion.UpgradeState
  alias MixVersion.Options
  alias MixVersion.Git

  def run(argv) do
    IO.puts([
      IO.ANSI.light_black(),
      "mix version v#{MixVersion.self_vsn()}",
      IO.ANSI.default_color()
    ])

    with {:ok, opts} <- Options.merge_cli_args(Options.from_env(), argv),
         {:ok, state} <- create_state(opts),
         state = UpgradeState.set_opts(state, opts),
         {:ok, _state} <- run_steps(state) do
      IO.puts("ok")
    else
      {:stop, reason} ->
        reason |> format_error |> yellow |> IO.puts()

      {:error, {:input_error, reason}} ->
        IO.puts(Options.usage())
        reason |> format_error |> red |> IO.puts()

      {:error, reason} ->
        reason |> format_error |> red |> IO.puts()
    end
  end

  defp create_state(opts) do
    if opts.git_only do
      UpgradeState.from_project_as_new()
    else
      UpgradeState.from_project()
    end
  end

  defp run_steps(state) do
    cond do
      state.opts.help ->
        [
          &show_help/1
        ]

      state.opts.git_only ->
        [
          &print_next_version/1,
          &check_git_repo/1,
          &git_add_files/1,
          &check_git_unstaged/1,
          &git_commit_and_tag/1
        ]

      true ->
        [
          &print_current_version/1,
          &maybe_prompt_version/1,
          &ensure_vsn_changed/1,
          &update_mixfile/1,
          &check_git_repo/1,
          &git_add_files/1,
          &check_git_unstaged/1,
          &git_commit_and_tag/1
        ]
    end
    |> reduce_ok(state, fn step, state -> call_step(step, state) end)
  end

  defp call_step(fun, state) when is_function(fun, 1),
    do: fun.(state)

  # -- STEPS ------------------------------------------------------------------

  defp show_help(state) do
    IO.puts(Options.usage())
    {:ok, state}
  end

  defp print_current_version(%{current_vsn: vsn} = state) do
    IO.puts("Current version: #{vsn}")
    {:ok, state}
  end

  defp print_next_version(%{next_vsn: vsn} = state) do
    IO.puts("New version: #{vsn}")
    {:ok, state}
  end

  defp maybe_prompt_version(%{next_vsn: nil} = state) do
    str = String.trim(Mix.Shell.IO.prompt("New version:    "))

    case Version.parse(str) do
      {:ok, vsn} -> {:ok, struct(state, next_vsn: vsn)}
      :error -> {:error, "Invalid version: #{str}"}
    end
  end

  defp maybe_prompt_version(state) do
    IO.puts("New version:     #{state.next_vsn}")
    {:ok, state}
  end

  defp ensure_vsn_changed(state) do
    case Version.compare(state.current_vsn, state.next_vsn) do
      :lt ->
        {:ok, state}

      :gt ->
        if Mix.Shell.IO.yes?(IO.iodata_to_binary(yellow("Confirm downgrade?"))),
          do: {:ok, state},
          else: {:error, "Cancelled downgrading version"}

      :eq ->
        {:error, "New version is the same as current version"}
    end
  end

  defp update_mixfile(state) do
    path = get_mixfile()

    with {:ok, content} <- File.read(path),
         {:ok, new_content} <- swap_mixfile_version(state, content),
         :ok <- File.write(path, new_content) do
      IO.puts("Wrote mixfile:   #{path}")
      {:ok, UpgradeState.add_changed_file(state, path)}
    else
      {:error, :eacces} -> {:error, "Could not access file #{path}, insufficient permissions"}
      {:error, :enoent} -> {:error, "Could not find file #{path}"}
      {:error, _} = err -> err
    end
  end

  defp get_mixfile() do
    Mix.Project.get().module_info(:compile)[:source] |> List.to_string()
  end

  defp swap_mixfile_version(state, content) do
    replace_schemes = [
      {~r/\bversion:\s+"#{state.current_vsn}"/, "version: \"#{state.next_vsn}\""},
      {~r/(?<=\s)@version\s+"#{state.current_vsn}"/, "@version \"#{state.next_vsn}\""}
    ]

    for {regex, replacement} <- replace_schemes, reduce: :error do
      :error ->
        if Regex.match?(regex, content) do
          {:ok, String.replace(content, regex, replacement)}
        else
          :error
        end

      {:ok, _content} = ok ->
        ok
    end
    |> case do
      :error -> {:error, "Could not find version to replace in mixfile"}
      ok -> ok
    end
  end

  defp check_git_repo(state) do
    with :ok <- Git.check_cmd(),
         {:ok, repo} <- Git.get_repo(File.cwd!()) do
      {:ok, %UpgradeState{state | git_repo: repo}}
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  defp check_git_unstaged(state) do
    case Git.get_unstaged(state.git_repo, ignore: state.changed_files) do
      {:ok, []} ->
        {:ok, state}

      {:ok, paths} ->
        IO.puts(yellow("Unstaged changes:"))
        IO.puts(yellow(paths |> Enum.map(&"  #{&1}") |> Enum.join("\n")))
        IO.puts(["Unstaged changes ", yellow("will not be added"), " to the commit"])

        if Mix.Shell.IO.yes?(IO.iodata_to_binary("Confirm commit & tag?")) do
          {:ok, state}
        else
          IO.puts(
            "tip: Use `mix version --git-only` to solely commit and tag with version #{state.next_vsn}"
          )

          {:stop, "Cancelled commiting to git."}
        end
    end
  end

  defp git_add_files(state) do
    with :ok <- do_add_files(state.git_repo, state.changed_files) do
      {:ok, state}
    end
  end

  defp do_add_files(repo, [file | files]) do
    case Git.add(repo, file) do
      :ok -> do_add_files(repo, files)
      err -> err
    end
  end

  defp do_add_files(_, []) do
    :ok
  end

  defp sprintf(format, replacement) do
    String.replace(format, "%s", replacement)
  end

  defp git_commit_and_tag(state) do
    vsn_str = to_string(state.next_vsn)
    commit_msg = sprintf(state.opts.commit_msg, vsn_str)
    tag_name = state.opts.tag_prefix <> vsn_str
    annotation = sprintf(state.opts.annotation, vsn_str)

    repo = state.git_repo

    tag_opts = [
      annotate: state.opts.annotate,
      annotation: annotation
    ]

    with :ok <- Git.check_tag_availability(repo, tag_name),
         :ok <- Git.commit(repo, commit_msg),
         :ok <- Git.tag(repo, tag_name, tag_opts) do
      {:ok, state}
    end
  end

  # -- HELPERS ----------------------------------------------------------------

  defp reduce_ok(enum, acc_in, fun) when is_function(fun, 2) do
    Enum.reduce(enum, {:ok, acc_in}, fn
      item, {:ok, acc} -> fun.(item, acc)
      _, {:error, reason} -> {:error, reason}
      _, {:stop, reason} -> {:stop, reason}
    end)
  end

  defp format_error(msg) when is_binary(msg),
    do: msg

  defp format_error(:no_git),
    do: "Git command not found"

  defp format_error(:tag_exists),
    do: "Git tag already exists"

  defp format_error(:no_git_repo),
    do: "Not in a git repository"

  defp format_error(:no_project_version) do
    """
    Could not figure out current version.
    Is #{File.cwd!()} a mix project?
    """
    |> String.trim()
  end

  defp format_error({:system_cmd, cmd, args, output, _}) do
    "Error when running command #{cmd} #{Enum.join(args, " ")}:\n" <>
      output
  end

  defp yellow(input),
    do: [IO.ANSI.yellow(), input, IO.ANSI.default_color()]

  defp red(input),
    do: [IO.ANSI.red(), input, IO.ANSI.default_color()]
end
