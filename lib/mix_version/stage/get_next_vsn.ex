defmodule MixVersion.Stage.GetNextVsn do
  @moduledoc """
  Decides on the new version number from the passed CLI options.
  """

  @behaviour MixVersion.Stage

  def applies?(_), do: true

  def run(%{current_vsn: current_vsn, opts: %{tag_current: false}} = token) do
    CliMate.CLI.writeln("Current version: #{current_vsn}")
    current = Version.parse!(current_vsn)

    with {:ok, next} <- get_next(current, token.opts),
         vsn = String.Chars.Version.to_string(next),
         print_next(vsn),
         :ok <- diff_versions(current, next) do
      {:ok, MixVersion.Token.put_next_vsn(token, vsn)}
    end
  end

  def run(%{current_vsn: current_vsn, opts: %{tag_current: true}} = token) do
    CliMate.CLI.writeln("Current version: #{current_vsn}")
    print_next(current_vsn)
    {:ok, MixVersion.Token.put_next_vsn(token, current_vsn)}
  end

  defp get_next(current_vsn, %{patch: true}), do: {:ok, bump(current_vsn, :patch)}
  defp get_next(current_vsn, %{minor: true}), do: {:ok, bump(current_vsn, :minor)}
  defp get_next(current_vsn, %{major: true}), do: {:ok, bump(current_vsn, :major)}
  defp get_next(_current_vsn, %{new_version: nil}), do: from_text(prompt())
  defp get_next(_current_vsn, %{new_version: v}) when is_binary(v), do: from_text(v)

  defp prompt do
    Process.put(:has_prompted_for_new_vsn, true)

    "New version:    "
    |> Mix.Shell.IO.prompt()
    |> String.trim()
  end

  defp print_next(vsn) do
    if Process.get(:has_prompted_for_new_vsn, false) do
      # no print as user input is shown
    else
      CliMate.CLI.writeln("New version:     #{vsn}")
    end
  end

  defp from_text(vsn) do
    case Version.parse(vsn) do
      {:ok, v} -> {:ok, v}
      :error -> {:error, "could not parse '#{vsn}' to a version number"}
    end
  end

  def bump(%Version{pre: [_ | _]} = vsn, :patch),
    do: Map.put(vsn, :pre, [])

  def bump(%Version{} = vsn, :patch),
    do: Map.update!(vsn, :patch, &(&1 + 1))

  def bump(%Version{minor: minor} = vsn, :minor),
    do: Map.merge(vsn, %{minor: minor + 1, patch: 0, pre: []})

  def bump(%Version{major: major} = vsn, :major),
    do: Map.merge(vsn, %{major: major + 1, minor: 0, patch: 0, pre: []})

  defp diff_versions(current, next) do
    case Version.compare(current, next) do
      :lt -> :ok
      :gt -> confirm_downgrade()
      :eq -> {:error, "new version is the same as current version"}
    end
  end

  defp confirm_downgrade do
    q? = IO.ANSI.format(CliMate.CLI.color(:yellow, "Confirm downgrade?"))

    if Mix.Shell.IO.yes?(:erlang.iolist_to_binary(q?), default: :no),
      do: :ok,
      else: {:stop, "Cancelled downgrading version"}
  end
end
