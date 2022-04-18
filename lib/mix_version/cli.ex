defmodule MixVersion.Cli do
  @moduledoc false
  def color(content, color),
    do: [apply(IO.ANSI, color, []), content, IO.ANSI.default_color()]

  def yellow(content), do: color(content, :yellow)
  def red(content), do: color(content, :red)
  def green(content), do: color(content, :green)
  def blue(content), do: color(content, :blue)
  def cyan(content), do: color(content, :cyan)
  def magenta(content), do: color(content, :magenta)
  def bright(content), do: [IO.ANSI.bright(), content, IO.ANSI.normal()]

  def abort do
    abort(1)
  end

  def abort(iodata) when is_list(iodata) or is_binary(iodata) do
    print(red(iodata))
    abort(1)
  end

  def abort(n) when is_integer(n) do
    _halt(n)
  end

  def success_stop(iodata) do
    success(iodata)
    _halt()
  end

  defp _halt(n \\ 0) do
    spawn(fn -> System.halt(n) end)
    Process.sleep(:infinity)
  end

  def success(iodata) do
    print(green(iodata))
  end

  def danger(iodata) do
    print(red(iodata))
  end

  def warn(iodata) do
    print(yellow(iodata))
  end

  def notice(iodata) do
    print(magenta(iodata))
  end

  def debug(iodata) do
    print(cyan(iodata))
  end

  def print(iodata) do
    IO.puts(iodata)
  end

  def ensure_string(str) when is_binary(str) do
    str
  end

  def ensure_string(term) do
    inspect(term)
  end

  defmodule Option do
    @moduledoc false
    @enforce_keys [:key, :doc, :type, :alias, :default, :keep]
    defstruct @enforce_keys

    @type vtype :: :integer | :float | :string | :count | :boolean
    @type t :: %__MODULE__{
            key: atom,
            doc: binary,
            type: vtype,
            alias: atom,
            default: term,
            keep: boolean
          }
  end

  defmodule Argument do
    @moduledoc false
    @enforce_keys [:key, :required, :cast]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            required: boolean,
            key: atom,
            cast: (term -> term)
          }
  end

  defmodule Command do
    @moduledoc false
    @enforce_keys [:arguments, :options, :module]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            arguments: [Argument.t()],
            options: %{atom => Option.t()},
            module: module
          }
  end

  def command(module) when is_atom(module),
    do: %Command{module: module, arguments: [], options: %{}}

  @type option_opt :: {:alias, atom} | {:doc, String.t()} | {:default, term}
  @type opt_conf :: [option_opt]

  @spec option(Command.t(), key :: atom, Option.vtype(), opt_conf) :: Command.t()
  def option(%Command{options: opts} = task, key, type, conf) do
    opt = make_option(key, type, conf)
    %Command{task | options: Map.put(opts, key, opt)}
  end

  defp make_option(key, type, conf) when is_atom(key) do
    keep = Keyword.get(conf, :keep, false)

    doc = Keyword.get(conf, :doc, "")

    alias_ = Keyword.get(conf, :alias, nil)

    default =
      case Keyword.fetch(conf, :default) do
        {:ok, term} -> {:default, term}
        :error -> :skip
      end

    %Option{key: key, doc: doc, type: type, alias: alias_, default: default, keep: keep}
  end

  @type argument_opt :: {:required, boolean()}
  @type arg_conf :: [argument_opt]

  @spec argument(Command.t(), key :: atom, arg_conf) :: Command.t()
  def argument(%Command{arguments: args} = task, key, conf) do
    arg = make_argument(key, conf)
    %Command{task | arguments: args ++ [arg]}
  end

  defp make_argument(key, conf) do
    required = Keyword.get(conf, :required, false)
    cast = Keyword.get(conf, :cast, & &1)
    %Argument{key: key, required: required, cast: cast}
  end

  def parse(%Command{options: opts} = task, argv) do
    strict = Enum.map(opts, fn {key, opt} -> {key, opt_to_switch(opt)} end)
    aliases = Enum.flat_map(opts, fn {_, opt} -> opt_alias(opt) end)

    case OptionParser.parse(argv, strict: strict, aliases: aliases) do
      {opts, args, []} ->
        opts = take_opts(task, opts)
        args = take_args(task, args)
        {opts, args}

      {_, _, invalid} ->
        print_usage(task)
        error_invalid_opts(invalid)
        abort()
    end
  end

  defp error_invalid_opts(kvs) do
    Enum.map(kvs, fn {k, _v} -> danger("invalid option #{k}") end)
  end

  defp usage_args(task) do
    task.arguments
    |> Enum.map(fn %Argument{key: key, required: req?} ->
      mark = if(req?, do: "", else: "*")
      "<#{key}>#{mark}"
    end)
    |> case do
      [] -> []
      list -> [" ", list]
    end
  end

  defp max_opt_name_width(task) do
    case map_size(task.options) do
      0 ->
        0

      _ ->
        Enum.reduce(task.options, 0, fn opt, acc ->
          opt
          |> elem(1)
          |> Map.fetch!(:key)
          |> Atom.to_string()
          |> String.length()
          |> max(acc)
        end)
    end
  end

  defp usage_options(task) do
    max_opt = max_opt_name_width(task) + 1

    columns = io_columns()

    # add space for the aliases, the "--" and the column gap
    left_blank = max_opt + 7

    task.options
    |> Enum.map(fn {key, %{alias: ali, doc: doc, type: type}} ->
      [
        case ali do
          nil -> "    "
          _ -> "-#{ali}, "
        end,
        bright(format_long_opt(key, max_opt)),
        format_opt_doc("#{type}. #{doc}", left_blank, columns),
        ?\n
      ]
    end)
    |> case do
      [] -> []
      opts -> ["Options:\n\n", opts]
    end
  end

  defp format_long_opt(key, max_opt) do
    name = key |> Atom.to_string() |> String.replace("_", "-")
    ["--", String.pad_trailing(name, max_opt, " ")]
  end

  defp io_columns do
    case :io.columns() do
      {:ok, n} -> n
      _ -> 100
    end
  end

  defp format_opt_doc(doc, pad, columns) do
    max_width = columns - pad
    padding = String.duplicate(" ", pad - 1)

    doc
    |> String.split("\n")
    |> Enum.map(&pad_left(&1, max_width, padding))
  end

  defp pad_left(line, max_width, padding) do
    line
    |> String.split(" ")
    |> shrink_text(0, max_width, padding)
  end

  defp shrink_text([word | words] = all, width, max_width, padding) do
    size = String.length(word) + 1

    cond do
      width == 0 and size >= max_width ->
        [?\n, padding, word, ?\n, padding | shrink_text(words, 0, max_width, padding)]

      width + size >= max_width ->
        [?\n, padding | shrink_text(all, 0, max_width, padding)]

      :_ ->
        [32, word | shrink_text(words, width + size, max_width, padding)]
    end
  end

  defp shrink_text([], _, _, _),
    do: []

  defp print_usage(task) do
    args = usage_args(task)

    options = usage_options(task)

    print([
      ?\n,
      cyan("mix #{Mix.Task.task_name(task.module)}#{args}"),
      ?\n,
      case Mix.Task.shortdoc(task.module) do
        nil -> []
        doc -> [?\n, doc, ?\n]
      end,
      ?\n,
      options
    ])
  end

  defp opt_to_switch(%{keep: true, type: t}), do: [t, :keep]
  defp opt_to_switch(%{keep: false, type: t}), do: t
  defp opt_alias(%{alias: nil}), do: []
  defp opt_alias(%{alias: a, key: key}), do: [{a, key}]

  defp take_opts(%Command{options: schemes}, opts) do
    Enum.reduce(schemes, %{}, fn scheme, acc -> collect_opt(scheme, opts, acc) end)
  end

  defp collect_opt({key, scheme}, opts, acc) do
    case scheme.keep do
      true ->
        list = collect_list_option(opts, key)
        Map.put(acc, key, list)

      false ->
        case get_opt_value(opts, key, scheme.default) do
          {:ok, value} -> Map.put(acc, key, value)
          :skip -> acc
        end
    end
  end

  def get_opt_value(opts, key, default) do
    case Keyword.fetch(opts, key) do
      :error ->
        case default do
          {:default, v} -> {:ok, v}
          :skip -> :skip
        end

      {:ok, v} ->
        {:ok, v}
    end
  end

  defp collect_list_option(opts, key) do
    opts |> Enum.filter(fn {k, _} -> k == key end) |> Enum.map(&elem(&1, 1))
  end

  defp take_args(%Command{arguments: schemes} = task, args) do
    take_args(schemes, args, %{})
  catch
    {:missing_argument, key} ->
      print_usage(task)

      abort("missing required argument <#{Atom.to_string(key)}>")
  end

  defp take_args([%{required: false} | _], [], acc) do
    acc
  end

  defp take_args([%{required: true, key: key} | _], [], _acc) do
    throw({:missing_argument, key})
  end

  defp take_args([%{key: key, cast: cast} | schemes], [value | argv], acc) do
    acc = Map.put(acc, key, cast.(value))
    take_args(schemes, argv, acc)
  end

  defp take_args([], [extra | _], _) do
    abort("unexpected argument #{inspect(extra)}")
  end

  defp take_args([], [], acc) do
    acc
  end
end
