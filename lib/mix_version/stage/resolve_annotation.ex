defmodule MixVersion.Stage.ResolveAnnotation do
  @moduledoc """
  Stage that builds the tag annotation for the new version, replacing all `%s`
  with the new version number.
  """

  @behaviour MixVersion.Stage

  def applies?(_), do: true

  def run(token) do
    annotation = String.replace(token.opts.annotation, "%s", token.next_vsn)

    case String.trim(annotation) do
      "" -> {:error, "the tag annotation is empty"}
      _ -> {:ok, MixVersion.Token.put_annotation(token, annotation)}
    end
  end
end
