defmodule MixVersionTest do
  use ExUnit.Case
  doctest MixVersion

  test "greets the world" do
    assert MixVersion.hello() == :world
  end
end
