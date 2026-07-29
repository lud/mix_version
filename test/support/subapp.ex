defmodule MixVersion.Support.Subapp do
  @moduledoc false

  # Test apps are built in three tiers:
  #
  # * The master is `test/subapp`, under version control, never modified.
  # * The secondary master is a well-known temporary directory built once per
  #   suite by `test_helper.exs`. It holds a compiled `mix_version` dependency
  #   and a Git repository with a single commit.
  # * Each test calls `create/0` to get its own copy of the secondary master in
  #   a Briefly directory, deps, build and Git history included. No compilation
  #   and no `git init` is needed there, which is what makes per-test isolation
  #   affordable.

  @subapp_mix_env "dev"
  @secondary_dirname "mix-version-subapp"
  @archives_dirname "mix-version-subapp-archives"

  # Entries of the master that are copied into the secondary master. Everything
  # else in the secondary master (deps, _build) is kept between runs.
  @master_entries ~w(mix.exs versioning.exs lib .gitignore)

  defp master_dir do
    Path.absname("test/subapp")
  end

  defp secondary_dir do
    Path.join(System.tmp_dir!(), @secondary_dirname)
  end

  # Root of this very project, injected in the environment of all commands so
  # the subapp mixfile can depend on the code under test.
  defp dep_root do
    Path.expand(File.cwd!())
  end

  # An empty archives directory, so a globally installed `mix_version` archive
  # cannot shadow the code under test in the subapps.
  defp archives_dir do
    Path.join(System.tmp_dir!(), @archives_dirname)
  end

  defp env do
    %{
      "MIX_ENV" => @subapp_mix_env,
      "MIX_ARCHIVES" => archives_dir(),
      "MIX_VERSION_DEP_ROOT" => dep_root()
    }
  end

  # -- Secondary master -------------------------------------------------------

  @doc """
  Builds the secondary master. Called from `test_helper.exs`, before the suite
  runs.
  """
  def build_secondary_master! do
    target = secondary_dir()
    File.mkdir_p!(target)
    File.mkdir_p!(archives_dir())

    Enum.each(@master_entries, fn entry ->
      _ = File.rm_rf!(Path.join(target, entry))
      _ = File.cp_r!(Path.join(master_dir(), entry), Path.join(target, entry))
    end)

    cmd!(target, "mix", ~w(deps.get))
    cmd!(target, "mix", ~w(compile))

    _ = File.rm_rf!(Path.join(target, ".git"))
    cmd!(target, "git", ~w(init -b main))
    cmd!(target, "git", ~w(config user.email subapp@example.com))
    cmd!(target, "git", ~w(config user.name Subapp))
    cmd!(target, "git", ~w(config commit.gpgsign false))
    cmd!(target, "git", ~w(config tag.gpgsign false))
    cmd!(target, "git", ~w(config core.hooksPath .git/hooks))
    cmd!(target, "git", ~w(add -A))
    cmd!(target, "git", ["commit", "-m", "initial commit"])

    :ok
  end

  # -- Test app lifecycle -----------------------------------------------------

  @doc """
  Returns the path of a fresh copy of the subapp. The directory is deleted when
  the calling process exits.
  """
  def create do
    dir = Briefly.create!(type: :directory)
    source = secondary_dir()

    Enum.each(File.ls!(source), fn entry ->
      _ = File.cp_r!(Path.join(source, entry), Path.join(dir, entry))
    end)

    assert_own_repo!(dir)
    dir
  end

  def write_file(dir, subpath, content) do
    path = Path.join(dir, subpath)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
    path
  end

  def read!(dir, subpath) do
    File.read!(Path.join(dir, subpath))
  end

  @doc """
  Sets the `:versioning` project configuration of the subapp and commits it.

  Accepts a keyword list, or a string when the configuration cannot be
  represented as a literal, typically to define hooks:

      Subapp.configure_versioning(dir, tag_prefix: "release/")

      Subapp.configure_versioning(dir, \"\"\"
      [before_commit: [fn vsn -> File.write!("VERSION", vsn) end, add: "VERSION"]]
      \"\"\")

  The subapp mixfile reads that configuration from its `versioning.exs` file, so
  the mixfile itself does not have to be rewritten.
  """
  def configure_versioning(dir, config) do
    _ = write_file(dir, "versioning.exs", versioning_source(config))
    commit(dir, "configure versioning")
  end

  defp versioning_source(source) when is_binary(source) do
    String.trim_trailing(source) <> "\n"
  end

  defp versioning_source(config) when is_list(config) do
    inspect(config, limit: :infinity, printable_limit: :infinity, pretty: true) <> "\n"
  end

  def commit(dir, message) do
    _ = git!(dir, ~w(add -A))
    _ = git!(dir, ["commit", "-m", message])
    :ok
  end

  # -- Running the task under test --------------------------------------------

  @doc """
  Runs `mix version` in the given subapp and returns `{output, exit_code}`.
  """
  def mix_version(dir, argv \\ []) do
    assert_own_repo!(dir)

    System.cmd("mix", ["version" | argv],
      cd: dir,
      stderr_to_stdout: true,
      env: env()
    )
  end

  @doc """
  Same as `mix_version/2` but raises if the command did not exit with `0`.
  """
  def mix_version!(dir, argv \\ []) do
    case mix_version(dir, argv) do
      {output, 0} ->
        output

      {output, code} ->
        IO.puts([IO.ANSI.yellow(), output, IO.ANSI.reset()])
        raise "mix version exited with status #{code}"
    end
  end

  # -- Git inspection ---------------------------------------------------------

  def git(dir, args) do
    System.cmd("git", args, cd: dir, stderr_to_stdout: true, env: env())
  end

  def git!(dir, args) do
    case git(dir, args) do
      {output, 0} -> String.trim_trailing(output)
      {output, code} -> raise "git #{Enum.join(args, " ")} exited with #{code}:\n#{output}"
    end
  end

  def tags(dir) do
    dir |> git!(~w(tag -l)) |> lines()
  end

  def log_subjects(dir) do
    dir |> git!(~w(log --format=%s)) |> lines()
  end

  @doc """
  Returns the type of the object the given tag points to: `"tag"` for an
  annotated tag, `"commit"` for a lightweight one.
  """
  def tag_type(dir, tag) do
    git!(dir, ["cat-file", "-t", tag])
  end

  def tag_message(dir, tag) do
    git!(dir, ["tag", "-l", "--format=%(contents)", tag])
  end

  def status(dir) do
    dir |> git!(~w(status --porcelain=v1)) |> lines()
  end

  # -- Helpers ----------------------------------------------------------------

  defp lines(""), do: []
  defp lines(output), do: output |> String.split("\n") |> Enum.map(&String.trim/1)

  # Ensures that the subapp directory is the root of its own Git repository, so
  # a broken setup can never make `mix version` commit or tag in the repository
  # of this very project.
  defp assert_own_repo!(dir) do
    top = git!(dir, ~w(rev-parse --show-toplevel))

    if same_dir?(top, dir) do
      :ok
    else
      raise "subapp #{dir} belongs to the Git repository at #{top}"
    end
  end

  defp same_dir?(left, right) do
    key = fn path ->
      stat = File.stat!(path)
      {stat.major_device, stat.inode}
    end

    key.(left) == key.(right)
  end

  defp cmd!(dir, cmd, args) do
    case System.cmd(cmd, args, cd: dir, stderr_to_stdout: true, env: env()) do
      {_, 0} ->
        :ok

      {output, code} ->
        IO.puts([IO.ANSI.yellow(), output, IO.ANSI.reset()])
        raise "#{cmd} #{Enum.join(args, " ")} exited with #{code} in #{dir}"
    end
  end
end
