defmodule MixVersion.Git do
  defmodule Repo do
    defstruct root: nil
  end

  def installed?() do
    case git(["--help"]) do
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
    case git(["rev-parse", "--show-toplevel"], cd: path, stderr_to_stdout: true) do
      {:ok, output} -> {:ok, struct(Repo, root: String.trim(output))}
      {:error, {:system_cmd, _, _, _, 128}} -> {:error, :no_git_repo}
    end
  end

  def get_unstaged(%Repo{root: root} = repo, opts \\ []) do
    case git(["status", "--porcelain=v1"], cd: root, stderr_to_stdout: true) do
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
        # parse the first char: the staged state, second char: unstaged state
        |> Enum.map(fn <<staged, unstaged, " ", path::binary>> -> {staged, unstaged, path} end)
    end
  end

  def add(%Repo{root: root} = repo, path) do
    with {:ok, relpath} <- relative_path(repo, path),
         {:ok, _} <- git(["add", relpath], cd: root) do
      {:ok, repo}
    end
  end

  def commit(%Repo{root: root} = repo, message) do
    with {:ok, _} <- git(["commit", "-m", message], cd: root, stderr_to_stdout: true) do
      {:ok, repo}
    end
  end

  def tag(%Repo{root: root} = repo, name) do
    with {:ok, _} <- git(["tag", name], cd: root, stderr_to_stdout: true) do
      {:ok, repo}
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

  defp git(args, opts \\ []), do: exec("git", args, opts)

  defp exec(cmd, args, opts) do
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
