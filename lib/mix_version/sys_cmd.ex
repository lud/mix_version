defmodule MixVersion.SysCmd do
  @moduledoc """
  Utiliy to run `System.cmd/3` with `:ok/:error` tuples results.
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
