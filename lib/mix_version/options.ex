defmodule MixVersion.Options do
  @default_tag_prefix "v"
  @default_commit_msg "%s"

  defstruct tag_prefix: @default_tag_prefix,
            commit_msg: @default_commit_msg,
            major: false,
            minor: false,
            patch: false,
            new_version: nil

  def from_env() do
    otp_app = Keyword.fetch!(Mix.Project.config(), :app)

    mv_config = Application.get_env(otp_app, :mix_version, [])

    struct(__MODULE__,
      tag_prefix: Keyword.get(mv_config, :tag_prefix, @default_tag_prefix),
      commit_msg: Keyword.get(mv_config, :commit_msg, @default_commit_msg)
    )
  end

  @cli_schema [
    strict: [
      new_version: :string,
      major: :boolean,
      minor: :boolean,
      patch: :boolean,
      tag_prefix: :string,
      commit_msg: :string
    ],
    aliases: [
      M: :major,
      m: :minor,
      p: :patch,
      n: :new_version
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

        {:error, errmsg}
    end
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

  defp plural(list), do: plural(list, "", "s")

  defp plural([_], str, _), do: str
  defp plural(_more, _, str), do: str
end
