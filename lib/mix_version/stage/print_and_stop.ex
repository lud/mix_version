defmodule MixVersion.Stage.PrintAndStop do
  @moduledoc """
  This stage checks for the output command and prints the version and halts
  the pipeline if the flag is provided.
  """
  alias MixVersion.Token

  @behaviour MixVersion.Stage

  def applies?(%Token{opts: %{info: info}}), do: !!info

  def run(%Token{current_vsn: vsn} = token) do
    IO.puts(vsn)
    {:halt, token}
  end
end
