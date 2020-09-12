defmodule MixVersion do
  @moduledoc File.read!("README.md")
             |> String.split("<!-- :title: -->", parts: 2)
             |> Enum.at(1)
end
