defmodule MixVersion.Git do
  defmodule Repo do
    defstruct root: nil
  end

  def installed?() do
    case exec("git", ["--help"]) do
      {:error, :command_not_found} -> false
      {:ok, _} -> true
    end
  end

  def check_cmd do
    if installed?() do
      :ok
    else
      {:error, :no_git}
    end
  end

  def get_repo(path) do
    case exec("git", ["rev-parse", "--show-toplevel"], cd: path, stderr_to_stdout: true) do
      {:ok, rootpath} -> {:ok, struct(Repo, root: String.trim(rootpath))}
      {:error, {:system_cmd, _, _, _, 128}} -> {:error, :no_git_repo}
    end
  end

  def get_unstaged(%Repo{} = repo, opts \\ []) do
    case git(repo, ["status", "--porcelain=v1"]) do
      {:ok, output} ->
        untracked =
          for {_, unstaged_state, path} <- parse_git_status(output), unstaged_state != ?\s do
            path
          end

        to_ignore = (opts[:ignore] || []) |> Enum.map(&relative_path!(repo, &1))
        {:ok, untracked -- to_ignore}

      err ->
        err
    end
  end

  def check_tag_availability(%Repo{} = repo, tag) when is_binary(tag) do
    case git(repo, ["tag", "-l"]) do
      {:ok, taglist} ->
        tags = String.split(taglist, "\n")

        if Enum.member?(tags, tag) do
          {:error, :tag_exists}
        else
          :ok
        end

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

  def add(%Repo{} = repo, path) do
    with {:ok, relpath} <- relative_path(repo, path),
         {:ok, _} <- git(repo, ["add", relpath]) do
      :ok
    end
  end

  def commit(%Repo{} = repo, message) do
    with {:ok, _} <- git(repo, ["commit", "-m", message]) do
      :ok
    end
  end

  def tag(%Repo{} = repo, name, opts) do
    args =
      if Keyword.get(opts, :annotate, false) do
        ["tag", name, "-a", "-m", Keyword.fetch!(opts, :annotation)]
      else
        ["tag", name]
      end

    with {:ok, _} <- git(repo, args) do
      :ok
    end
  end

  def relative_path!(%Repo{root: root} = repo, path) do
    case relative_path(repo, path) do
      {:ok, rel} -> rel
      {:error, _} -> raise "Could not figure out relative path from #{root} for #{path}"
    end
  end

  def relative_path(%Repo{root: root}, root),
    do: {:ok, "."}

  def relative_path(%Repo{root: root}, path) do
    case Path.relative_to(path, root) do
      ^path -> {:error, :external_path}
      rel -> {:ok, rel}
    end
  end

  defp git(%Repo{root: root}, args, opts \\ []) when is_list(args) do
    opts =
      opts
      |> Keyword.put_new(:stderr_to_stdout, true)
      |> Keyword.put_new(:cd, root)

    exec("git", args, opts)
  end

  defp exec(cmd, args, opts \\ []) do
    case System.cmd(cmd, args, opts) do
      {output, 0} ->
        {:ok, String.trim_trailing(output)}

      {output, exit_code} ->
        {:error, {:system_cmd, cmd, args, String.trim_trailing(output), exit_code}}
    end
  rescue
    e in ErlangError ->
      %ErlangError{original: :enoent} = e
      {:error, :command_not_found}
  end
end
