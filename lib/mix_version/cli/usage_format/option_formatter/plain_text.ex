defmodule MixVersion.CLI.UsageFormat.OptionFormatter.PlainText do
  alias MixVersion.CLI.Argument
  alias MixVersion.CLI.Option

  @moduledoc false

  @behaviour MixVersion.CLI.UsageFormat

  # padding on the left of the options block
  @left_padding "  "
  @left_padding_len String.length(@left_padding)

  defp left_padding, do: @left_padding

  @impl true
  def format_head(title, docs, fmt_opts) do
    case docs do
      nil -> format_heading(title, fmt_opts)
      _ -> format_section(title, docs, fmt_opts)
    end
  end

  @impl true
  def format_synopsis(iodata, fmt_opts) do
    if Keyword.get(fmt_opts, :ansi_enabled, false) do
      ["  ", cyan(iodata)]
    else
      ["  ", iodata]
    end
  end

  @impl true
  def format_section(title, content, fmt_opts) do
    [format_heading(title, fmt_opts), "\n\n", content]
  end

  defp format_heading(title, fmt_opts) do
    if Keyword.get(fmt_opts, :ansi_enabled, false) do
      bright(title)
    else
      title
    end
  end

  @impl true
  def section_margin, do: "\n\n"

  @impl true
  def format_arguments(command, fmt_opts) do
    columns = Keyword.get_lazy(fmt_opts, :io_columns, &io_columns/0)
    ansi_enabled? = Keyword.get(fmt_opts, :ansi_enabled, false)
    doc_width = columns - @left_padding_len
    doc_padding = [?\n, left_padding()]

    Enum.map_intersperse(command.arguments, "\n\n", fn arg ->
      title = arg_title(arg, ansi_enabled?)

      case format_doc(arg, doc_width, doc_padding) do
        :no_doc -> [left_padding(), title]
        doc -> [left_padding(), title, doc]
      end
    end)
  end

  defp arg_title(arg, ansi_enabled?) do
    if ansi_enabled?, do: bright(Atom.to_string(arg.key)), else: Atom.to_string(arg.key)
  end

  @impl true
  def format_options(command, fmt_opts) do
    columns = Keyword.get_lazy(fmt_opts, :io_columns, &io_columns/0)
    ansi_enabled? = Keyword.get(fmt_opts, :ansi_enabled, false)

    options = command.options
    has_short_opts? = Enum.any?(options, fn {_, %{short: short}} -> short != nil end)

    signatures = Enum.map(options, &signature(&1, ansi_enabled?, has_short_opts?))

    {doc_padding, doc_padding_len} =
      if has_short_opts? do
        # ..................... "-x, --"
        {[?\n, left_padding(), "      "], @left_padding_len + 6}
      else
        # ..................... "--"
        {[?\n, left_padding(), "  "], @left_padding_len + 2}
      end

    doc_width = columns - doc_padding_len

    docs = Enum.map(options, &format_doc(&1, doc_width, doc_padding))

    opts_docs =
      Enum.zip_with(signatures, docs, fn
        signature, :no_doc ->
          [left_padding(), signature, ?\n]

        signature, doc ->
          [left_padding(), signature, doc, ?\n]
      end)

    Enum.intersperse(opts_docs, ?\n)
  end

  defp signature({_, option}, ansi_enabled?, shorts?) do
    iodata_short = short_signature(option, ansi_enabled?, shorts?)
    iodata_long = long_signature(option, ansi_enabled?)
    [iodata_short, iodata_long]
  end

  defp short_signature(option, ansi_enabled?, shorts?) do
    %Option{short: short} = option

    if shorts? do
      case short do
        nil -> ["    "]
        s when ansi_enabled? -> [bright(["-", Atom.to_string(s)]), ", "]
        s -> ["-", Atom.to_string(s), ", "]
      end
    else
      []
    end
  end

  defp long_signature(option, ansi_enabled?) do
    %Option{type: type} = option
    name = name(option)

    signature =
      case type do
        t when t in [:boolean, :count] and ansi_enabled? ->
          [bright(["--", name])]

        t when t in [:boolean, :count] ->
          ["--", name]

        _ when ansi_enabled? ->
          doc_arg = option.doc_arg
          [bright(["--", name]), cyan([" <", doc_arg, ">"])]

        _ ->
          doc_arg = option.doc_arg
          ["--", name, " <", doc_arg, ">"]
      end

    if type == :count || option.keep do
      [signature, " (repeatable)"]
    else
      signature
    end
  end

  defp format_doc(%Argument{} = argument, width, pad_text) do
    %{doc: doc} = argument

    case doc do
      "" ->
        :no_doc

      _ ->
        doc
        |> unwrap_doc()
        |> wrap_doc(width)
        |> Enum.map(&[pad_text, &1])
    end
  end

  defp format_doc({_, %Option{} = option}, width, pad_text) do
    %Option{
      key: k,
      doc: doc,
      default: default,
      default_doc: default_doc
    } = option

    doc =
      case {k, default} do
        {:help, _} -> doc
        {_, :skip} -> doc
        {_, {:default, v}} -> [doc, " ", [format_default(k, v, default_doc)]]
      end

    case doc do
      "" ->
        :no_doc

      _ ->
        doc
        |> unwrap_doc()
        |> wrap_doc(width)
        |> Enum.map(&[pad_text, &1])
    end
  end

  defp name(%Option{key: key}) do
    key |> Atom.to_string() |> String.replace("_", "-")
  end

  defp io_columns do
    case :io.columns() do
      {:ok, n} -> n
      _ -> 78
    end
  end

  defp bright(iodata), do: [IO.ANSI.bright(), iodata, IO.ANSI.reset()]
  defp cyan(iodata), do: [IO.ANSI.cyan(), iodata, IO.ANSI.reset()]

  defp unwrap_doc(doc) do
    doc
    |> IO.chardata_to_string()
    |> String.trim()
    |> String.replace("\n", " ")
    |> String.replace(~r/\s+/, " ")
  end

  defp wrap_doc(doc, width) do
    words =
      doc
      |> String.split(" ")
      |> Enum.map(&{&1, String.length(&1)})

    words
    |> Enum.reduce({0, [], []}, fn {word, len}, {line_len, this_line, lines} ->
      cond do
        line_len == 0 -> {len, [word | this_line], lines}
        line_len + 1 + len > width -> {len, [word], [:lists.reverse(this_line) | lines]}
        :_ -> {line_len + 1 + len, [word, " " | this_line], lines}
      end
    end)
    |> case do
      {_, [], lines} -> :lists.reverse(lines)
      {_, current, lines} -> :lists.reverse([:lists.reverse(current) | lines])
    end
  end

  defp format_default(_k, _value, default_doc) when is_binary(default_doc) do
    default_doc
  end

  defp format_default(k, value, _) when is_function(value, 1) do
    IO.warn([
      "Option ",
      inspect(k),
      " should document the default value using :default_doc option."
    ])

    "Dynamic default value."
  end

  defp format_default(_, value, _) do
    ["Defaults to ", inspect(value), "."]
  end
end
