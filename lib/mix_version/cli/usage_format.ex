defmodule MixVersion.CLI.UsageFormat do
  alias MixVersion.CLI.Command
  alias MixVersion.CLI.UsageFormat.OptionFormatter.Markdown
  alias MixVersion.CLI.UsageFormat.OptionFormatter.PlainText

  @moduledoc false

  @type fmt_opt :: {:io_columns, pos_integer} | {:ansi_enabled, boolean}
  @type fmt_opts :: [fmt_opt]

  @callback format_head(header :: iodata, doc :: iodata | nil, fmt_opts) :: iodata() | nil
  @callback format_synopsis(iodata, fmt_opts) :: iodata()
  @callback format_section(title :: String.t(), content :: iodata(), fmt_opts) :: iodata()
  @callback section_margin() :: iodata()

  @doc """
  This callback is only called if there is at least one argument.
  """
  @callback format_arguments(command :: Command.t(), fmt_opts) :: iodata()

  @doc """
  Formats an option block for the command. There is always at least one option
  for each command, the `--help` option, so there is no need to check if the
  options are an empty list.
  """
  @callback format_options(command :: Command.t(), fmt_opts) :: iodata()

  defp adapter(opts) do
    case Keyword.fetch!(opts, :format) do
      :moduledoc -> Markdown
      :cli -> PlainText
    end
  end

  def format_command(command, fmt_opts) do
    opts = Keyword.merge(default_fmt_opts(), fmt_opts)
    adapter = adapter(opts)

    head =
      adapter.format_head(
        [format_command_name(command), format_command_version(command)],
        command.doc,
        fmt_opts
      )

    synopsis_section =
      adapter.format_section(
        "Synopsis",
        adapter.format_synopsis(synopsis_line(command), fmt_opts),
        fmt_opts
      )

    arguments_section =
      case command.arguments do
        [] ->
          nil

        _ ->
          adapter.format_section(
            "Arguments",
            adapter.format_arguments(command, fmt_opts),
            fmt_opts
          )
      end

    options_section =
      adapter.format_section("Options", adapter.format_options(command, fmt_opts), fmt_opts)

    [head, synopsis_section, arguments_section, options_section]
    |> Enum.reject(&is_nil/1)
    |> Enum.intersperse(adapter.section_margin())
  end

  defp default_fmt_opts do
    [format: :cli]
  end

  defp synopsis_line(command) do
    call = format_command_name(command)

    argslist =
      case command do
        %{arguments: []} -> ""
        %{arguments: args} -> format_usage_args_list(args)
      end

    [call, " [options]", argslist]
  end

  defp format_command_name(command) do
    case command do
      %Command{name: nil, module: nil} ->
        "unnamed command"

      %Command{name: name} when is_binary(name) ->
        name

      %Command{module: mod} when is_atom(mod) and mod != nil ->
        mod
        |> Module.split()
        |> case do
          ["Mix", "Tasks" | rest] ->
            "mix #{Enum.map_join(rest, ".", &Macro.underscore/1)}"

          _ ->
            inspect(mod)
        end
    end
  end

  defp format_command_version(command) do
    vsn =
      case command do
        %{version: vsn} when is_binary(vsn) -> vsn
        %{module: nil} -> nil
        %{module: mod} -> module_to_vsn(mod)
      end

    case vsn do
      nil -> []
      vsn -> [" version ", vsn]
    end
  end

  defp module_to_vsn(module) do
    with otp_app when otp_app != nil <- Application.get_application(module),
         [_ | _] = spec <- Application.spec(otp_app),
         {:ok, vsn} <- Keyword.fetch(spec, :vsn) do
      vsn
    else
      _ -> nil
    end
  end

  defp format_usage_args_list([%{required: req?, key: key} | rest]) do
    name = Atom.to_string(key)

    case req? do
      true -> [" <", name, ">" | format_usage_args_list(rest)]
      false -> [[" [<", name, ">" | format_usage_args_list(rest)], "]"]
    end
  end

  defp format_usage_args_list([]) do
    []
  end
end
