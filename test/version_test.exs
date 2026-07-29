defmodule MixVersion.VersionTest do
  alias MixVersion.Support.Subapp
  use ExUnit.Case, async: true

  test "bumping the patch version" do
    dir = Subapp.create()

    Subapp.mix_version!(dir, ~w(-p))

    assert Subapp.read!(dir, "mix.exs") =~ ~s(version: "0.1.1")
    assert "v0.1.1" in Subapp.tags(dir)
    assert "new version 0.1.1" == hd(Subapp.log_subjects(dir))
    assert [] == Subapp.status(dir)
  end

  test "bumping the minor version" do
    dir = Subapp.create()

    Subapp.mix_version!(dir, ~w(-m))

    assert Subapp.read!(dir, "mix.exs") =~ ~s(version: "0.2.0")
    assert "v0.2.0" in Subapp.tags(dir)
  end

  test "bumping the major version" do
    dir = Subapp.create()

    Subapp.mix_version!(dir, ~w(-M))

    assert Subapp.read!(dir, "mix.exs") =~ ~s(version: "1.0.0")
    assert "v1.0.0" in Subapp.tags(dir)
  end

  test "setting an explicit version" do
    dir = Subapp.create()

    Subapp.mix_version!(dir, ~w(-n 1.2.3))

    assert Subapp.read!(dir, "mix.exs") =~ ~s(version: "1.2.3")
    assert "v1.2.3" in Subapp.tags(dir)
  end

  test "customizing the commit message and the tag prefix" do
    dir = Subapp.create()

    Subapp.mix_version!(dir, ["-p", "--commit-msg", "release %s", "--tag-prefix", "rel-"])

    assert "release 0.1.1" == hd(Subapp.log_subjects(dir))
    assert "rel-0.1.1" in Subapp.tags(dir)
  end

  test "the tag annotation is customizable" do
    dir = Subapp.create()

    Subapp.mix_version!(dir, ["-p", "--annotation", "shipped %s"])

    assert Subapp.tag_message(dir, "v0.1.1") =~ "shipped 0.1.1"
  end

  test "defaults are read from the versioning project configuration" do
    dir = Subapp.create()
    Subapp.configure_versioning(dir, commit_msg: "bump to %s", tag_prefix: "release/")

    Subapp.mix_version!(dir, ~w(-p))

    assert "bump to 0.1.1" == hd(Subapp.log_subjects(dir))
    assert "release/0.1.1" in Subapp.tags(dir)
  end

  test "command line options override the versioning project configuration" do
    dir = Subapp.create()
    Subapp.configure_versioning(dir, tag_prefix: "release/")

    Subapp.mix_version!(dir, ["-p", "--tag-prefix", "from-cli-"])

    assert "from-cli-0.1.1" in Subapp.tags(dir)
  end

  test "a before_commit hook runs and can stage files into the version commit" do
    dir = Subapp.create()

    Subapp.configure_versioning(dir, """
    [
      before_commit: [
        fn vsn -> File.write!("VERSION", vsn) end,
        add: "VERSION"
      ]
    ]
    """)

    Subapp.mix_version!(dir, ~w(-p))

    assert "0.1.1" == Subapp.read!(dir, "VERSION")
    assert [] == Subapp.status(dir)
    assert Subapp.git!(dir, ~w(show HEAD --name-only --format=%s)) =~ "VERSION"
  end

  test "the version of the subapp is reported by --info" do
    dir = Subapp.create()

    assert "0.1.0" == dir |> Subapp.mix_version!(~w(--info)) |> String.trim()
  end

  test "other files staged in the index are included in the version commit" do
    dir = Subapp.create()
    Subapp.write_file(dir, "NOTES.md", "some notes\n")
    _ = Subapp.git!(dir, ~w(add NOTES.md))

    Subapp.mix_version!(dir, ~w(-p))

    assert [] == Subapp.status(dir)
    assert Subapp.git!(dir, ~w(show HEAD --name-only --format=%s)) =~ "NOTES.md"
  end
end
