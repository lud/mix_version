defmodule MixVersion.Stage.ApplyHook do
  @moduledoc """
  Stage that applies the hooks configured under a given key of the
  `:versioning` project configuration, such as `:before_commit`.
  """

  @behaviour MixVersion.Stage

  def applies?(_), do: true

  @doc """
  Applies the hooks registered in the token under the given key.

  A hook is either a function that receives the next version and returns `:ok`
  or `{:error, reason}`, or an `add: path` entry that stages the file at
  `path` to the Git index. Execution stops at the first hook returning an
  error.
  """
  def run(token, key) do
    case apply_hook(token.hooks[key], token) do
      {:ok, token} ->
        {:ok, token}

      {:error, _} = err ->
        err

      {:invalid, other} ->
        {:error,
         "Hook #{inspect(key)} returned invalid result, expected :ok or {:error, binary}, got: #{inspect(other)}"}
    end
  end

  defp apply_hook([hook | hooks], token) do
    case apply_hook(hook, token) do
      {:ok, token} -> apply_hook(hooks, token)
      {:error, _} = err -> err
      other -> {:invalid, other}
    end
  end

  defp apply_hook([], token) do
    {:ok, token}
  end

  defp apply_hook(f, token) when is_function(f) do
    case f.(token.next_vsn) do
      :ok ->
        {:ok, token}

      {:error, _} = err ->
        err

      other ->
        {:invalid, other}
    end
  end

  defp apply_hook({:add, path}, token) when is_binary(path) do
    if is_struct(token.git_repo) do
      with :ok <- MixVersion.Git.add(token.git_repo, path) do
        MixVersion.CLI.writeln("Staged #{path} to Git index")
        {:ok, token}
      end
    else
      {:error, "Could not stage #{path} to Git index, no Git repository was found"}
    end
  end
end
