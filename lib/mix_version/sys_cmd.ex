defmodule MixVersion.SysCmd do
  @moduledoc """
  Utility to run `System.cmd/3` with `:ok/:error` tuples results.
  """

  @doc """
  Runs a command with `System.cmd/3` and wraps the result in an ok/error tuple.

  The options are passed to `System.cmd/3`. Returns `{:ok, output}` with
  trailing whitespace trimmed when the command exits with a zero status,
  `{:error, {:system_cmd, cmd, args, output, exit_code}}` when the exit status
  is not zero, and `{:error, :command_not_found}` when the executable cannot
  be found.

  ### Examples

      iex> MixVersion.SysCmd.exec("echo", ["hello"])
      {:ok, "hello"}
  """
  def exec(cmd, args, opts \\ []) do
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
