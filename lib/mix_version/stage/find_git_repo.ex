defmodule MixVersion.Stage.FindGitRepo do
  @moduledoc """
  Finds the root path of the Git repository of the project, if any.
  """

  @behaviour MixVersion.Stage

  def applies?(%{git_cmd?: has_git?}), do: has_git?

  def run(token) do
    case MixVersion.Git.get_repo(File.cwd!()) do
      {:ok, repo} ->
        CliMate.CLI.debug("found Git repository at #{repo.root}")
        {:ok, MixVersion.Token.put_git_repo(token, repo)}

      {:error, :no_git_repo} ->
        CliMate.CLI.warn("project is not in a git repository")
        {:ok, token}
    end
  end
end
