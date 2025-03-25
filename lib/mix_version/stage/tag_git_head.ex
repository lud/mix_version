defmodule MixVersion.Stage.TagGitHead do
  @moduledoc """
  Stage that creates a possibly annotated tag at the current Git HEAD.
  """

  def applies?(%{git_cmd?: has_git, git_repo: repo}), do: has_git && is_struct(repo)

  def run(token) do
    tag_name = tag_name(token)

    annotation =
      case token.opts do
        %{annotate: true} -> String.replace(token.opts.annotation, "%s", token.next_vsn)
        _ -> nil
      end

    tag_opts = [
      annotate: token.opts.annotate,
      annotation: annotation
    ]

    with :ok <- MixVersion.Git.tag(token.git_repo, tag_name, tag_opts) do
      CliMate.CLI.writeln("created tag #{tag_name}")
      {:ok, token}
    end
  end

  def tag_name(token) do
    token.opts.tag_prefix <> token.next_vsn
  end
end
