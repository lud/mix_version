defmodule MixVersion.GitTest do
  alias MixVersion.Git
  alias MixVersion.Support.Subapp
  use ExUnit.Case, async: true

  # `MixVersion.Git` never reads the current Mix project, it only needs a
  # repository path. It can therefore be exercised in-process, against a real
  # repository, which `mix test --cover` can actually measure.

  defp repo(dir) do
    {:ok, repo} = Git.get_repo(dir)
    repo
  end

  test "git is installed" do
    assert Git.installed?()
  end

  test "finding the repository of a path" do
    dir = Subapp.create()
    assert {:ok, %Git.Repo{root: root}} = Git.get_repo(dir)
    assert File.stat!(root).inode == File.stat!(dir).inode
  end

  test "a directory outside of any repository" do
    dir = Briefly.create!(type: :directory)
    assert {:error, :no_git_repo} = Git.get_repo(dir)
  end

  test "listing unstaged files" do
    dir = Subapp.create()
    repo = repo(dir)

    assert {:ok, []} = Git.get_unstaged(repo)

    File.write!(Path.join(dir, "NOTES.md"), "notes\n")
    assert {:ok, ["NOTES.md"]} = Git.get_unstaged(repo)

    assert :ok = Git.add(repo, "NOTES.md")
    assert {:ok, []} = Git.get_unstaged(repo)
  end

  test "modified tracked files are reported as unstaged" do
    dir = Subapp.create()
    repo = repo(dir)

    File.write!(Path.join(dir, "versioning.exs"), "[annotate: false]\n")
    assert {:ok, ["versioning.exs"]} = Git.get_unstaged(repo)
  end

  test "adding a path outside of the repository" do
    dir = Subapp.create()
    outside = Briefly.create!(type: :directory)

    assert {:error, {:external_path, ^outside}} = Git.add(repo(dir), outside)
  end

  test "adding a path that does not exist" do
    dir = Subapp.create()

    assert {:error, {:no_such_file, "nope.md"}} = Git.add(repo(dir), "nope.md")
  end

  test "resolving a path relative to the repository root" do
    dir = Subapp.create()
    repo = repo(dir)

    assert "mix.exs" == Git.path_relative_to(Path.join(dir, "mix.exs"), repo)
    assert "." == Git.path_relative_to(repo.root, repo)
  end

  test "committing staged changes" do
    dir = Subapp.create()
    repo = repo(dir)

    File.write!(Path.join(dir, "NOTES.md"), "notes\n")
    :ok = Git.add(repo, "NOTES.md")

    assert :ok = Git.commit(repo, "add notes")
    assert "add notes" == hd(Subapp.log_subjects(dir))
  end

  test "committing without changes fails unless empty commits are allowed" do
    dir = Subapp.create()
    repo = repo(dir)

    assert {:error, {:system_cmd, "git", _, _, _}} = Git.commit(repo, "nothing")
    assert :ok = Git.commit(repo, "nothing", allow_empty: true)
    assert "nothing" == hd(Subapp.log_subjects(dir))
  end

  test "checking tag availability" do
    dir = Subapp.create()
    repo = repo(dir)

    assert {:ok, true} = Git.check_tag_availability(repo, "v1.0.0")
    :ok = Git.tag(repo, "v1.0.0", annotation: "release")
    assert {:ok, false} = Git.check_tag_availability(repo, "v1.0.0")
  end

  test "tagging the repository head" do
    dir = Subapp.create()
    repo = repo(dir)

    assert :ok = Git.tag(repo, "v1.0.0", annotation: "first release")
    assert "v1.0.0" in Subapp.tags(dir)
    assert Subapp.tag_message(dir, "v1.0.0") =~ "first release"
  end

  test "tagging with an already used name" do
    dir = Subapp.create()
    repo = repo(dir)

    :ok = Git.tag(repo, "v1.0.0", annotation: "release")

    assert {:error, {:system_cmd, "git", _, output, _}} =
             Git.tag(repo, "v1.0.0", annotation: "release")

    assert output =~ "already exists"
  end
end
