defmodule MixVersion.Stage.Confirm do
  @moduledoc """
  Stage that prints the commit message and the tag that will be created, and
  asks for confirmation before any change is made to the project.
  """

  @behaviour MixVersion.Stage

  @label_width 17

  def applies?(%{opts: opts}), do: Map.get(opts, :confirm, false)

  def run(token) do
    MixVersion.CLI.writeln(summary(token))

    if Mix.Shell.IO.yes?("Proceed?", default: :no) do
      {:ok, token}
    else
      {:stop, "canceled"}
    end
  end

  defp summary(%{git_cmd?: true, git_repo: %{}} = token) do
    [
      ?\n,
      field("Tag name:", MixVersion.Stage.TagGitHead.tag_name(token)),
      field("Commit message:", token.commit_msg),
      field("Tag annotation:", token.annotation)
    ]
  end

  defp summary(token) do
    [?\n, field("Version:", token.next_vsn)]
  end

  defp field(label, text) do
    indent = String.duplicate(" ", @label_width)
    [first | rest] = text |> String.trim() |> String.split("\n")

    rest =
      Enum.map(rest, fn
        "" -> ?\n
        line -> [?\n, indent, line]
      end)

    [String.pad_trailing(label, @label_width), first, rest, ?\n]
  end
end
