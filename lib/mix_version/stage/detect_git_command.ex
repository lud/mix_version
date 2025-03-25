defmodule MixVersion.Stage.DetectGitCommand do
  @moduledoc """
  Stage that checks if the `git` command is callable with `System.cmd/3`.
  """

  @behaviour MixVersion.Stage

  def applies?(_), do: true

  def run(token) do
    git? = MixVersion.Git.installed?()

    case git? do
      true -> CliMate.CLI.debug("git command found")
      false -> CliMate.CLI.warn("git command not found")
    end

    {:ok, MixVersion.Token.put_git_cmd?(token, git?)}
  end
end
