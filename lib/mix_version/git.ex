defmodule MixVersion.Git do
  @moduledoc """
  This module is a simple, ad-hoc interface to the Git CLI.
  """

  import MixVersion.SysCmd

  defmodule Repo do
    @moduledoc false
    defstruct root: nil
  end

  # Git translates its messages according to the locale defined in the
  # environment, and this module parses the output of some commands. Messages
  # are therefore pinned to English. `LC_ALL` and `LANGUAGE` are unset as both
  # take precedence over `LC_MESSAGES`.
  @git_env [{"LC_MESSAGES", "C"}, {"LC_ALL", nil}, {"LANGUAGE", nil}]

  defp git(%Repo{root: root}, args, opts \\ []) when is_list(args) do
    opts =
      opts
      |> Keyword.put_new(:stderr_to_stdout, true)
      |> Keyword.put_new(:cd, root)
      |> Keyword.put_new(:env, @git_env)

    exec("git", args, opts)
  end

  @doc """
  Returns whether the `git` command is available on the system.
  """
  def installed? do
    case exec("git", ["--help"], env: @git_env) do
      {:error, :command_not_found} -> false
      {:ok, _} -> true
    end
  end

  @doc """
  Returns `{:ok, repo}` where `repo` represents the Git repository containing
  the given path.

  Returns `{:error, :no_git_repo}` when the path does not belong to a Git work
  tree.
  """
  def get_repo(path) do
    case exec("git", ["rev-parse", "--show-toplevel"],
           cd: path,
           stderr_to_stdout: true,
           env: @git_env
         ) do
      {:ok, rootpath} -> {:ok, struct(Repo, root: String.trim(rootpath))}
      {:error, {:system_cmd, _, _, _, 128}} -> {:error, :no_git_repo}
    end
  end

  @doc """
  Returns `{:ok, paths}` where `paths` lists the files of the repository with
  unstaged changes, including untracked files.
  """
  def get_unstaged(%Repo{} = repo) do
    case git(repo, ["status", "--porcelain=v1"]) do
      {:ok, output} ->
        untracked =
          for {_, unstaged_state, path} <- parse_git_status(output), unstaged_state != ?\s do
            path
          end

        {:ok, untracked}

      err ->
        err
    end
  end

  defp parse_git_status(status_out) do
    status_out
    |> String.trim_trailing()
    |> String.replace("\r\n", "\n")
    |> case do
      "" ->
        []

      out ->
        out
        |> String.split("\n")
        |> Enum.filter(fn
          "warning:" <> _ -> false
          _ -> true
        end)
        # parse the first char: the staged state, second char: unstaged state
        |> Enum.map(fn <<staged, unstaged, " ", path::binary>> -> {staged, unstaged, path} end)
    end
  end

  defp relative_path!(%Repo{root: root} = repo, path) do
    case relative_path(repo, path) do
      {:ok, rel} -> rel
      {:error, _} -> raise "Could not figure out relative path from #{root} for #{path}"
    end
  end

  defp relative_path(%Repo{root: root}, root),
    do: {:ok, "."}

  defp relative_path(%Repo{root: root}, path) do
    case Path.type(path) do
      :absolute ->
        case Path.relative_to(path, root) do
          ^path -> {:error, {:external_path, path}}
          rel -> {:ok, rel}
        end

      :relative ->
        abs = Path.join(root, path)

        if File.exists?(abs) do
          {:ok, path}
        else
          {:error, {:no_such_file, path}}
        end
    end
  end

  @doc """
  Returns the given path relative to the repository root.

  Raises when the path is outside of the repository or does not exist.
  """
  def path_relative_to(path, %Repo{} = repo) do
    relative_path!(repo, path)
  end

  @doc """
  Stages the file at the given path to the Git index.
  """
  def add(%Repo{} = repo, path) do
    with {:ok, relpath} <- relative_path(repo, path),
         {:ok, _} <- git(repo, ["add", relpath]) do
      :ok
    end
  end

  @doc """
  Creates a Git commit with the given message.

  ### Options

  * `:allow_empty` - when `true`, passes the `--allow-empty` flag so the commit
    is created even when the index contains no change.
  """
  def commit(%Repo{} = repo, message, opts \\ []) do
    args = ["-m", message]

    args =
      case opts[:allow_empty] do
        true -> ["--allow-empty" | args]
        _ -> args
      end

    args = ["commit" | args]

    with {:ok, _} <- git(repo, args) do
      :ok
    end
  end

  @doc """
  Checks that the given tag name is not already used in the repository.

  Returns `{:ok, true}` when the tag is available, `{:ok, false}` when a tag
  with that name already exists.
  """
  def check_tag_availability(%Repo{} = repo, tag) when is_binary(tag) do
    case git(repo, ["tag", "-l"]) do
      {:ok, taglist} ->
        tags = taglist |> String.split("\n") |> Enum.map(&String.trim/1)

        {:ok, not Enum.member?(tags, tag)}

      err ->
        err
    end
  end

  @doc """
  Creates a Git tag with the given name at the current HEAD.

  ### Options

  * `:annotation` - required, the tag message.
  * `:annotate` - when `true`, creates an annotated tag carrying the
    annotation message. Defaults to `false`.
  """
  def tag(%Repo{} = repo, name, opts) do
    message = Keyword.fetch!(opts, :annotation)
    args = ["tag", name, "-m", message]

    args =
      if Keyword.get(opts, :annotate, false),
        do: args ++ ["-a"],
        else: args

    with {:ok, _} <- git(repo, args), do: :ok
  end
end
