defmodule MixVersion.Stage.ApplyHook do
  @moduledoc """
  Stage that creates a new Git commit with the updated `mix.exs` file and all
  other changes added to the Git index.
  """

  @behaviour MixVersion.Stage

  def applies?(_), do: true

  def run(token, key) do
    case apply_hook(token.hooks[key], token) do
      {:ok, token} ->
        {:ok, token}

      {:error, _} = err ->
        err

      {:invalid, other} ->
        CliMate.CLI.halt_error(
          "Hook #{inspect(key)} returned invalid result, expected :ok or {:error, binary}, got: #{inspect(other)}"
        )
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
    with :ok <- MixVersion.Git.add(token.git_repo, path) do
      CliMate.CLI.writeln("Staged #{path} to Git index")
      {:ok, token}
    end
  end
end
