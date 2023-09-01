defmodule MixVersion.Stage.CommitChanges do
  @moduledoc """
  Stage that creates a new Git commit with the updated `mix.exs` file and all
  other changes added to the Git index.
  """

  @behaviour MixVersion.Stage

  def applies?(%{git_cmd?: has_git, git_repo: repo}), do: has_git && is_struct(repo)

  def run(token) do
    commit_msg_tpl = token.opts.commit_msg
    commit_msg = String.replace(commit_msg_tpl, "%s", token.next_vsn)

    with :ok <- MixVersion.Git.commit(token.git_repo, commit_msg) do
      MixVersion.CLI.debug("committed changes to git")
      {:ok, token}
    end
  end
end
