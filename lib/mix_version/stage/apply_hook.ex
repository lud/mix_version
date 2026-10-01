defmodule MixVersion.Stage.ApplyHook do
  @moduledoc """
  Stage that applies the hooks configured under a given key of the
  `:versioning` project configuration, such as `:before_commit`.
  """

  @behaviour MixVersion.Stage

  def applies?(_), do: true

  @doc """
  Applies the hooks registered in the token under the given key.

  A hook is either a function or an `add: path` entry that stages the file at
  `path` to the Git index. Functions return `:ok` or `{:error, reason}` and
  receive the next version, and with arity 2 a map with the following keys as
  the second argument:

  * `:current_vsn` - The current version, as a string.
  * `:next_vsn` - The next version, as a string. This is also the first
    argument.
  * `:next_version` - The next version, as a `Version` struct.
  * `:tag_name` - The name of the Git tag that will be created, including the
    tag prefix.
  * `:annotation` - The tag annotation, with all `%s` replaced by the next
    version.

  Execution stops at the first hook returning an error.
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

      {:invalid_hook, other} ->
        {:error,
         "Hook #{inspect(key)} is invalid, expected a function of arity 1 or 2, or {:add, path}, got: #{inspect(other)}"}
    end
  end

  defp apply_hook([hook | hooks], token) do
    case apply_hook(hook, token) do
      {:ok, token} -> apply_hook(hooks, token)
      {:error, _} = err -> err
      {:invalid, _} = invalid -> invalid
      {:invalid_hook, _} = invalid -> invalid
    end
  end

  defp apply_hook([], token) do
    {:ok, token}
  end

  defp apply_hook(f, token) when is_function(f, 1) do
    handle_result(f.(token.next_vsn), token)
  end

  defp apply_hook(f, token) when is_function(f, 2) do
    handle_result(f.(token.next_vsn, hook_info(token)), token)
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

  defp apply_hook(other, _token) do
    {:invalid_hook, other}
  end

  defp hook_info(token) do
    %{
      current_vsn: token.current_vsn,
      next_vsn: token.next_vsn,
      next_version: Version.parse!(token.next_vsn),
      tag_name: MixVersion.Stage.TagGitHead.tag_name(token),
      annotation: token.annotation
    }
  end

  defp handle_result(:ok, token), do: {:ok, token}
  defp handle_result({:error, _} = err, _token), do: err
  defp handle_result(other, _token), do: {:invalid, other}
end
