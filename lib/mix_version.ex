defmodule MixVersion do
  @external_resource "README.md"
  @moduledoc File.read!("README.md")
             |> String.split("<!-- :title: -->", parts: 2)
             |> Enum.at(1)
end
