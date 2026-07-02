defmodule MixVersion.DoctestsTest do
  use ExUnit.Case, async: true

  doctest MixVersion.Config
  doctest MixVersion.SysCmd
end
