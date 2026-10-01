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

  test "the tag annotation can be read from a file" do
    dir = Subapp.create()
    path = Briefly.create!()
    File.write!(path, "shipped %s\n\nwith notes\n")

    Subapp.mix_version!(dir, ["-p", "--annotation-file", path])

    assert "shipped 0.1.1\n\nwith notes" == String.trim(Subapp.tag_message(dir, "v0.1.1"))
  end

  test "the annotation file replaces the configured annotation" do
    dir = Subapp.create()
    Subapp.configure_versioning(dir, annotation: "configured %s")
    path = Briefly.create!()
    File.write!(path, "from file %s")

    Subapp.mix_version!(dir, ["-p", "-F", path])

    assert "from file 0.1.1" == String.trim(Subapp.tag_message(dir, "v0.1.1"))
  end

  test "tags are annotated" do
    dir = Subapp.create()

    Subapp.mix_version!(dir, ~w(-p))

    # An annotated tag is a git object of type "tag" carrying the message. A
    # lightweight tag is only a ref to the commit, so its type would be
    # "commit".
    assert "tag" == Subapp.tag_type(dir, "v0.1.1")
  end

  test "the deprecated --annotate flag is accepted and ignored" do
    dir = Subapp.create()

    output = Subapp.mix_version!(dir, ~w(-p --no-annotate))

    assert output =~ "option --annotate is deprecated"
    assert "tag" == Subapp.tag_type(dir, "v0.1.1")
  end

  test "the annotate project configuration is ignored" do
    dir = Subapp.create()
    Subapp.configure_versioning(dir, annotate: false)

    output = Subapp.mix_version!(dir, ~w(-p))

    refute output =~ "annotate"
    assert "tag" == Subapp.tag_type(dir, "v0.1.1")
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

  test "a before_commit hook of arity 2 receives the annotation from a file" do
    dir = Subapp.create()

    Subapp.configure_versioning(dir, """
    [
      before_commit: [
        fn _vsn, info -> File.write!("NOTES", info.annotation) end,
        add: "NOTES"
      ]
    ]
    """)

    path = Briefly.create!()
    File.write!(path, "intro for %s\n")

    Subapp.mix_version!(dir, ["-p", "-F", path])

    assert "intro for 0.1.1\n" == Subapp.read!(dir, "NOTES")
    assert "intro for 0.1.1" == String.trim(Subapp.tag_message(dir, "v0.1.1"))
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
