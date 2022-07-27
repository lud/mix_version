defmodule MixVersion.Stage.PrintAndStop do
  @moduledoc """
  This stage checks for the output command and prints the version and exists if
  the flag is provided.
  """
  alias MixVersion.Token

  def applies?(%Token{opts: %{info: info}}), do: !!info

  @spec run(Token.t()) :: no_return()
  def run(%Token{current_vsn: vsn}) do
    IO.puts(vsn)
    System.halt()
  end
end
