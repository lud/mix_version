defmodule MixVersion.ExecTest do
  alias MixVersion.Support.Subapp
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  # These tests run the whole stage pipeline in the test VM through
  # `Mix.Tasks.Version.exec/1`, with an environment map pointing at a subapp
  # directory. Argument parsing and reading the Mix project are covered by the
  # end-to-end tests in `version_test.exs`.

  @opts_defaults %{
    info: false,
    major: false,
    minor: false,
    patch: false,
    new_version: nil,
    annotate: true,
    commit_msg: "new version %s",
    annotation: "new version %s",
    tag_prefix: "v",
    tag_current: false
  }

  defp env(dir, opts, extra \\ []) do
    %{
      opts: Map.merge(@opts_defaults, Map.new(opts)),
      hooks: %{before_commit: Keyword.get(extra, :before_commit, [])},
      current_vsn: Keyword.get(extra, :current_vsn, "0.1.0"),
      mixfile_path: Path.join(dir, "mix.exs"),
      cwd: dir
    }
  end

  defp exec(env) do
    result = Mix.Tasks.Version.exec(env)

    # The pipeline must give control back to the caller. With the process shell
    # a call to `CLI.halt/1` only sends a message and lets the remaining stages
    # run, so a test could pass while the real CLI aborts the run.
    refute_received {:cli_mate_shell, :halt, _}

    result
  end

  test "bumping the patch version" do
    dir = Subapp.create()

    assert {:ok, token} = exec(env(dir, patch: true))

    assert "0.1.1" == token.next_vsn
    assert Subapp.read!(dir, "mix.exs") =~ ~s(version: "0.1.1")
    assert "v0.1.1" in Subapp.tags(dir)
    assert "new version 0.1.1" == hd(Subapp.log_subjects(dir))
    assert [] == Subapp.status(dir)
  end

  test "the mixfile version can be defined as a module attribute" do
    dir = Subapp.create()

    _ =
      Subapp.write_file(dir, "mix.exs", """
      defmodule Subapp.MixProject do
        use Mix.Project

        @version "0.1.0"

        def project do
          [app: :subapp, version: @version]
        end
      end
      """)

    :ok = Subapp.commit(dir, "use a version attribute")

    assert {:ok, _} = exec(env(dir, minor: true))
    assert Subapp.read!(dir, "mix.exs") =~ ~s(@version "0.2.0")
  end

  test "a mixfile without the current version cannot be updated" do
    dir = Subapp.create()

    assert {:error, "Could not find version to replace in mixfile"} =
             exec(env(dir, [patch: true], current_vsn: "9.9.9"))
  end

  test "the info option prints the current version and halts the pipeline" do
    dir = Subapp.create()
    test_env = env(dir, info: true)

    output =
      capture_io(fn ->
        assert {:ok, _} = exec(test_env)
      end)

    assert "0.1.0\n" == output
    # No git state was touched
    assert [] == Subapp.tags(dir)
  end

  test "bump options are mutually exclusive" do
    dir = Subapp.create()

    assert {:error, "Options --patch" <> _} = exec(env(dir, patch: true, minor: true))
  end

  test "an unparseable new version is rejected" do
    dir = Subapp.create()

    assert {:error, "could not parse 'wat' to a version number"} =
             exec(env(dir, new_version: "wat"))
  end

  test "the new version must differ from the current one" do
    dir = Subapp.create()

    assert {:error, "new version is the same as current version"} =
             exec(env(dir, new_version: "0.1.0"))
  end

  test "an existing tag with the target name aborts the run" do
    dir = Subapp.create()
    _ = Subapp.git!(dir, ["tag", "v0.1.1", "-m", "already here"])

    assert {:error, "tag v0.1.1 already exists"} = exec(env(dir, patch: true))
  end

  test "an unstaged mixfile aborts the run" do
    dir = Subapp.create()
    _ = Subapp.write_file(dir, "mix.exs", Subapp.read!(dir, "mix.exs") <> "# dirty\n")

    assert {:error, "file mix.exs has unstaged changes"} = exec(env(dir, patch: true))
  end

  test "before_commit hooks receive the next version and can stage files" do
    dir = Subapp.create()

    hooks = [
      fn vsn -> File.write!(Path.join(dir, "VERSION"), vsn) end,
      {:add, "VERSION"}
    ]

    assert {:ok, _} = exec(env(dir, [patch: true], before_commit: hooks))

    assert "0.1.1" == Subapp.read!(dir, "VERSION")
    assert [] == Subapp.status(dir)
    assert Subapp.git!(dir, ~w(show HEAD --name-only --format=%s)) =~ "VERSION"
  end

  test "a hook returning an error aborts the run" do
    dir = Subapp.create()
    hooks = [fn _vsn -> {:error, "boom"} end]

    assert {:error, "boom"} = exec(env(dir, [patch: true], before_commit: hooks))
    assert [] == Subapp.tags(dir)
  end

  test "a hook returning an invalid value aborts the run" do
    dir = Subapp.create()
    hooks = [fn _vsn -> :wat end]

    assert {:error, message} = exec(env(dir, [patch: true], before_commit: hooks))
    assert message =~ "Hook :before_commit returned invalid result"
    assert message =~ ":wat"
  end

  test "outside of a git repository the mixfile is still updated" do
    dir = Briefly.create!(type: :directory)
    _ = Subapp.write_file(dir, "mix.exs", ~s([app: :subapp, version: "0.1.0"]\n))

    assert {:ok, _} = exec(env(dir, patch: true))
    assert Subapp.read!(dir, "mix.exs") =~ ~s(version: "0.1.1")
  end

  test "outside of a git repository a staging hook aborts the run" do
    dir = Briefly.create!(type: :directory)
    _ = Subapp.write_file(dir, "mix.exs", ~s([app: :subapp, version: "0.1.0"]\n))
    hooks = [{:add, "VERSION"}]

    assert {:error, "Could not stage VERSION to Git index" <> _} =
             exec(env(dir, [patch: true], before_commit: hooks))

    # The mixfile is updated after the hooks, so the run stopped before it
    assert Subapp.read!(dir, "mix.exs") =~ ~s(version: "0.1.0")
  end

  test "tagging the current version creates an empty commit" do
    dir = Subapp.create()

    assert {:ok, token} = exec(env(dir, tag_current: true))

    assert "0.1.0" == token.next_vsn
    assert "v0.1.0" in Subapp.tags(dir)
    assert "new version 0.1.0" == hd(Subapp.log_subjects(dir))
  end
end
