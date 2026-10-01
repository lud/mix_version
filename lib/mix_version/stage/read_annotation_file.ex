defmodule MixVersion.Stage.ReadAnnotationFile do
  @moduledoc """
  Stage that reads the tag annotation from the file given with the
  `--annotation-file` option, before any change is made to the project.
  """

  @behaviour MixVersion.Stage

  def applies?(%{opts: opts}), do: Map.has_key?(opts, :annotation_file)

  def run(token) do
    path = token.opts.annotation_file

    case File.read(Path.expand(path, token.cwd)) do
      {:ok, annotation} ->
        opts =
          token.opts
          |> Map.delete(:annotation_file)
          |> Map.put(:annotation, annotation)

        {:ok, MixVersion.Token.put_opts(token, opts)}

      {:error, reason} ->
        {:error, "could not read annotation file #{path}: #{:file.format_error(reason)}"}
    end
  end
end
