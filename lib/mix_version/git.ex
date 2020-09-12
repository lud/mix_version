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

  def add(%Repo{root: root} = repo, path) do
    with {:ok, relpath} <- relative_path(repo, path),
         {:ok, _} <- git(["add", relpath], cd: root) do
      {:ok, repo}
    end
  end

  def commit(%Repo{root: root} = repo, message) do
    with {:ok, _} <- git(["commit", "-m", message], cd: root) do
      {:ok, repo}
    end
  end

  def tag(%Repo{root: root} = repo, name) do
    with {:ok, _} <- git(["tag", name], cd: root) do
      {:ok, repo}
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
