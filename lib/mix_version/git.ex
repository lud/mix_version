defmodule MixVersion.Git do
  @moduledoc """
  This module is a simple, ad-hoc interface to the Git CLI.
  """

  import MixVersion.SysCmd

  defmodule Repo do
    @moduledoc false
    defstruct root: nil
  end

  defp git(%Repo{root: root}, args, opts \\ []) when is_list(args) do
    opts =
      opts
      |> Keyword.put_new(:stderr_to_stdout, true)
      |> Keyword.put_new(:cd, root)

    exec("git", args, opts)
  end

  def installed? do
    case exec("git", ["--help"]) do
      {:error, :command_not_found} -> false
      {:ok, _} -> true
    end
  end

  def get_repo(path) do
    case exec("git", ["rev-parse", "--show-toplevel"], cd: path, stderr_to_stdout: true) do
      {:ok, rootpath} -> {:ok, struct(Repo, root: String.trim(rootpath))}
      {:error, {:system_cmd, _, _, _, 128}} -> {:error, :no_git_repo}
    end
  end

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

  def path_relative_to(path, %Repo{} = repo) do
    relative_path!(repo, path)
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

  def check_tag_availability(%Repo{} = repo, tag) when is_binary(tag) do
    case git(repo, ["tag", "-l"]) do
      {:ok, taglist} ->
        tags = taglist |> String.split("\n") |> Enum.map(&String.trim/1)

        {:ok, not Enum.member?(tags, tag)}

      err ->
        err
    end
  end

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
