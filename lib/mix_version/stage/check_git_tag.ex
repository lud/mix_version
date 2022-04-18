defmodule MixVersion.Stage.CheckGitTag do
  @moduledoc """
  Stage that checks that the future Git tag does not already exist.
  """

  @behaviour MixVersion.Stage

  def applies?(%{git_cmd?: has_git, git_repo: repo}), do: has_git && is_struct(repo)

  def run(token) do
    tag_name = MixVersion.Stage.TagGitHead.tag_name(token)

    case MixVersion.Git.check_tag_availability(token.git_repo, tag_name) do
      {:ok, false} -> {:error, "tag #{tag_name} already exists"}
      {:ok, true} -> {:ok, token}
      {:error, _} = err -> err
    end
  end
end
