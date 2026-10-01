defmodule MixVersion.Stage.CommitChanges do
  @moduledoc """
  Stage that creates a new Git commit with the updated `mix.exs` file and all
  other changes added to the Git index.
  """

  @behaviour MixVersion.Stage

  def applies?(%{git_cmd?: has_git, git_repo: repo}), do: has_git && is_struct(repo)

  def run(token) do
    allow_empty? =
      case token.opts do
        %{tag_current: true} -> true
        _ -> false
      end

    with :ok <- MixVersion.Git.commit(token.git_repo, token.commit_msg, allow_empty: allow_empty?) do
      MixVersion.CLI.debug("committed changes to git")
      {:ok, token}
    end
  end
end
