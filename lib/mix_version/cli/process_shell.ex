defmodule MixVersion.CLI.ProcessShell do
  @tag :cli_mate_shell

  @moduledoc false

  @type kind :: :error | :warn | :debug | :info
  @type shell_message :: {unquote(@tag), kind, iodata()}

  @doc false
  def _print(_output, kind, iodata) do
    send(message_target(), build_message(kind, format_message(iodata)))
  end

  @spec build_message(kind, iodata) :: {unquote(@tag), kind, iodata()}
  def build_message(kind, iodata) do
    {@tag, kind, format_message(iodata)}
  end

  defp format_message(iodata) do
    iodata
    |> IO.ANSI.format(false)
    |> :erlang.iolist_to_binary()
  end

  @doc """
  Returns the pid of the process that will receive output messages.
  """
  def message_target do
    case Process.get(:"$callers") do
      [parent | _] -> parent
      _ -> self()
    end
  end

  def _halt(n) do
    send(message_target(), {@tag, :halt, n})
  end
end
