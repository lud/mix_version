defmodule MixVersion do
  @external_resource "README.md"
  @moduledoc File.read!("README.md")
             |> String.split("<!-- :title: -->", parts: 2)
             |> Enum.at(1)
  @self_vsn to_string(Keyword.fetch!(Mix.Project.config(), :version))

  def self_vsn do
    @self_vsn
  end
end
