defmodule MixVersion.Stage.TagGitHead do
  @moduledoc """
  Stage that creates an annotated tag at the current Git HEAD.
  """

  @behaviour MixVersion.Stage

  def applies?(%{git_cmd?: has_git, git_repo: repo}), do: has_git && is_struct(repo)

  def run(token) do
    tag_name = tag_name(token)

    with :ok <- MixVersion.Git.tag(token.git_repo, tag_name, annotation: token.annotation) do
      MixVersion.CLI.writeln("created tag #{tag_name}")
      {:ok, token}
    end
  end

  @doc """
  Returns the Git tag name for the token's next version, prepending the
  configured tag prefix.
  """
  def tag_name(token) do
    token.opts.tag_prefix <> token.next_vsn
  end
end
