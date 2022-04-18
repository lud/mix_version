defmodule MixVersion.BumpTest do
  use ExUnit.Case

  test "bump regular version" do
    assert bump("1.2.3", :patch) === "1.2.4"
    assert bump("1.2.3", :minor) === "1.3.0"
    assert bump("1.2.3", :major) === "2.0.0"
  end

  test "bump pre releases" do
    assert bump("1.2.3-RC2", :patch) === "1.2.3"
    assert bump("1.2.3-RC2", :minor) === "1.3.0"
    assert bump("1.2.3-RC2", :major) === "2.0.0"
  end

  defp bump(s, part) do
    s
    |> Version.parse!()
    |> MixVersion.Stage.GetNextVsn.bump(part)
    |> to_string
  end
end
