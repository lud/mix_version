defmodule MixVersion.Stage.ResolveMessages do
  @moduledoc """
  Stage that builds the commit message and the tag annotation for the new
  version, replacing all `%s` with the new version number.
  """

  alias MixVersion.Token

  @behaviour MixVersion.Stage

  def applies?(_), do: true

  def run(token) do
    commit_msg = String.replace(token.opts.commit_msg, "%s", token.next_vsn)
    annotation = String.replace(token.opts.annotation, "%s", token.next_vsn)

    case String.trim(annotation) do
      "" ->
        {:error, "the tag annotation is empty"}

      _ ->
        {:ok, token |> Token.put_commit_msg(commit_msg) |> Token.put_annotation(annotation)}
    end
  end
end
