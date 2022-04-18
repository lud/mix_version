defmodule MixVersion.Stage do
  @moduledoc """
  Behaviour for mix version stages.
  """

  @callback applies?(MixVersion.Token.t()) :: boolean()
  @callback run(MixVersion.Token.t()) ::
              {:ok, MixVersion.Token.t()} | {:error, term} | {:stop, term}
  @optional_callbacks run: 1
end
