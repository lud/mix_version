defmodule MixVersion.Stage.CheckUnstaged do
  @moduledoc """
  Checks if any file in the project has changes that are not committed to Git.

  * If the project's `mix.exs` file has unstagged changes, `mix version` will
    abort, refusing to go any further.
  * If other files have changes, the app will prompt for confirmation to
    continue.
  """

  @behaviour MixVersion.Stage

  def applies?(%{git_cmd?: has_git, git_repo: repo}), do: has_git && is_struct(repo)

  def run(token) do
    with {:ok, unstaged_files} <- MixVersion.Git.get_unstaged(token.git_repo) do
      check_unstaged(token, unstaged_files)
    end
  end

  defp check_unstaged(token, []) do
    {:ok, token}
  end

  defp check_unstaged(token, unstaged_files) do
    mixfile = Mix.Project.project_file() |> MixVersion.Git.path_relative_to(token.git_repo)

    if mixfile in unstaged_files do
      {:error, "file #{mixfile} has unstaged changes"}
    else
      print_unstaged(unstaged_files)

      if Mix.Shell.IO.yes?("Commit and tag as-is?", default: :no) do
        {:ok, token}
      else
        {:stop, "cancelled"}
      end
    end
  end

  defp print_unstaged(unstaged_files) do
    MixVersion.Cli.warn([
      "A new commit with the current staged files will be created.",
      ?\n,
      "The following files have changes that are not staged to git " <>
        "and will not be included in that commit:\n",
      Enum.map(unstaged_files, &["– ", &1, ?\n]),
      ?\n,
      "Note that you may add the files to the Git index from another terminal " <>
        "before moving on. All changes to Git will be included in the commit.",
      ?\n
    ])
  end
end
