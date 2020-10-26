defmodule MixVersion.Options do
  defstruct tag_prefix: "v",
            commit_msg: "%s",
            annotation: "%s",
            annotate: false,
            new_version: nil,
            major: false,
            minor: false,
            patch: false,
            git_only: false,
            help: false

  def from_env() do
    struct(__MODULE__, Map.new(Application.get_all_env(:mix_version)))
  end

  @cli_schema [
    strict: [
      new_version: :string,
      major: :boolean,
      minor: :boolean,
      patch: :boolean,
      tag_prefix: :string,
      commit_msg: :string,
      git_only: :boolean,
      annotate: :boolean,
      annotation: :string,
      help: :boolean
    ],
    aliases: [
      M: :major,
      m: :minor,
      p: :patch,
      n: :new_version,
      g: :git_only,
      a: :annotate,
      A: :annotation,
      c: :commit_msg,
      x: :tag_prefix
    ]
  ]

  def merge_cli_args(state, argv) do
    with {:ok, opts} <- parse_argv(argv),
         {:ok, opts} <- transform_opts(opts) do
      {:ok, struct!(state, opts)}
    end
  end

  defp parse_argv(argv) do
    # We do not expect any args at all
    case OptionParser.parse(argv, @cli_schema) do
      {opts, [], []} ->
        {:ok, opts}

      {_, args, invalid} ->
        errmsg =
          [
            # Format invalid opts
            case Enum.map(invalid, &elem(&1, 0)) do
              [] -> nil
              keys -> "Invalid option#{plural(keys)}: #{Enum.join(keys, ", ")}"
            end,
            # Format invalid positional
            case args do
              [] -> nil
              args -> "Unexpected argument#{plural(args)}: #{Enum.join(args, ", ")}"
            end
          ]
          |> Enum.filter(&(&1 != nil))
          |> Enum.join("\n")

        {:error, {:input_error, errmsg}}
    end
  end

  def usage do
    """

    OPTIONS
    -M  --major                        Bump the major number.
    -m  --minor                        Bump the minor number.
    -p  --patch                        Bump the patch number.
    -n  --new-version                  Directly enter the new version number.
    -x  --tag-prefix <prefix>          Override the tag prefix.
    -c  --commit-msg <format>          Override the commit message format.
    -a  --annotate                     Create an annotated git tag.
    -A  --annotation <format>          Override the annotation message format.
    -g  --git-only                     Commit and tag with the current version.
        --help                         Shows this help block.
    """
  end

  defp transform_opts(opts) do
    # Validate unique flags
    conflict_opts =
      opts
      |> Keyword.take([:major, :minor, :new_version, :patch])
      |> Enum.filter(&elem(&1, 1))
      |> Enum.map(&elem(&1, 0))
      |> Enum.map(fn k -> "--#{k}" end)

    if length(conflict_opts) > 1 do
      throw({:error, "Those options are mutually exclusive: #{Enum.join(conflict_opts, ", ")}"})
    end

    # Validate the new version

    opts =
      Keyword.update(opts, :new_version, nil, fn str ->
        case Version.parse(str) do
          {:ok, vsn} -> vsn
          :error -> throw({:error, "Invalid version #{str}"})
        end
      end)

    {:ok, opts}
  catch
    {:error, _} = err -> err
  end

  # # Copy all values from overrides into map for keys that are in both maps.
  # defp override_map(map, overrides) when is_map(map) and is_map(overrides) do
  #   Enum.reduce(Map.keys(map), map, fn
  #     :__struct__, map ->
  #       map

  #     key, map ->
  #       case Map.fetch(overrides, key) do
  #         {:ok, new_value} -> Map.put(map, key, new_value)
  #         :error -> map
  #       end
  #   end)
  # end

  defp plural(list), do: plural(list, "", "s")

  defp plural([_], str, _), do: str
  defp plural(_more, _, str), do: str
end
