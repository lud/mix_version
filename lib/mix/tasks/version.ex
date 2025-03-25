defmodule Mix.Tasks.Version do
  alias MixVersion.CLI
  import MixVersion.Config
  use Mix.Task

  @readme File.cwd!()
          |> Path.join("README.md")
          |> File.read!()
          |> String.split("<!-- doc-start -->")
          |> Enum.at(1)
          |> String.split("<!-- doc-end -->")
          |> hd()

  @command [
    module: __MODULE__,
    options: [
      info: [
        type: :boolean,
        short: :i,
        doc: "Only outputs the current version and stops. Ignores all other options.",
        default: false
      ],
      major: [type: :boolean, short: :M, doc: "Bump to a new major version.", default: false],
      minor: [type: :boolean, short: :m, doc: "Bump to a new minor version.", default: false],
      patch: [type: :boolean, short: :p, doc: "Bump the patch version.", default: false],
      new_version: [type: :string, short: :n, doc: "Set the new version number.", default: nil],
      annotate: [type: :boolean, short: :a, doc: "Create an annotated git tag."],
      commit_msg: [
        type: :string,
        short: :c,
        doc: "Define the commit message, with all '%s' replaced by the new VSN."
      ],
      annotation: [
        type: :string,
        short: :A,
        doc: "Define the tag annotation message, with all '%s' replaced by the new VSN."
      ],
      tag_prefix: [type: :string, short: :x, doc: "Define the tag prefix."],
      tag_current: [
        type: :boolean,
        short: :k,
        default: false,
        doc: "Commit and tag with the current version."
      ]
    ]
  ]

  @usage CLI.format_usage(@command, format: :moduledoc)
  @moduledoc """
  This module implements a mix task whose main purpose is to update the version
  number of an Elixir application, with extra steps such as committing a git
  tag.

  #{@readme}

  #{@usage}
  """

  @shortdoc "Manages the version of an Elixir application"

  @doc false
  def run(argv) do
    command =
      CLI.parse_or_halt!(
        argv,
        @command
      )

    %{options: opts} = command

    opts =
      opts
      |> defaults_from_project()
      |> check_mutex_opts()

    hooks = collect_hooks()

    token = MixVersion.Token.new(current_vsn(), opts, hooks)

    stages = [
      MixVersion.Stage.PrintAndStop,
      MixVersion.Stage.DetectGitCommand,
      MixVersion.Stage.FindGitRepo,
      MixVersion.Stage.CheckUnstaged,
      MixVersion.Stage.GetNextVsn,
      MixVersion.Stage.CheckGitTag,
      {MixVersion.Stage.ApplyHook, [:before_commit]},
      MixVersion.Stage.UpdateMixfile,
      MixVersion.Stage.CommitChanges,
      MixVersion.Stage.TagGitHead
    ]

    run_stages(stages, token)
  end

  defp current_vsn do
    _vsn = MixVersion.Config.project_get(:version)
  end

  defp run_stages(stages, token) do
    Enum.reduce(stages, token, fn stage, token ->
      case run_stage(stage, token) do
        {:ok, %MixVersion.Token{} = token} ->
          # token |> Map.put(:opts, :_) |> IO.inspect(label: "new token")
          token

        {:error, reason} ->
          reason |> to_iodata() |> CLI.halt_error()

        {:stop, reason} ->
          reason |> to_iodata() |> CLI.warn()
          CLI.halt()
      end
    end)
  end

  defp run_stage(stage, token) when is_atom(stage) do
    run_stage({stage, []}, token)
  end

  defp run_stage({module, args}, token) when is_list(args) do
    if module.applies?(token) do
      apply(module, :run, [token | args])
    else
      {:ok, token}
    end
  end

  defp to_iodata(reason) when is_binary(reason), do: reason
  defp to_iodata(reason) when is_list(reason), do: Enum.map(reason, &_to_iodata/1)
  defp to_iodata(reason), do: _to_iodata(reason)
  defp _to_iodata(reason) when is_binary(reason), do: reason
  defp _to_iodata(reason) when is_integer(reason), do: reason
  defp _to_iodata(reason) when is_list(reason), do: Enum.map(reason, &_to_iodata/1)
  defp _to_iodata(reason), do: inspect(reason)

  @project_defaults annotate: true,
                    commit_msg: "new version %s",
                    annotation: "new version %s",
                    tag_prefix: "v"

  defp defaults_from_project(cli_opts) do
    project = current_project()

    project_config =
      Map.new(@project_defaults, fn {k, default_val} ->
        value =
          case project_get(project, [:versioning, k], nil) do
            nil -> default_val
            value -> value
          end

        {k, value}
      end)

    Map.merge(project_config, cli_opts)
  end

  defp collect_hooks do
    project = current_project()

    keys = [:before_commit]

    Map.new(keys, fn k ->
      value = project_get(project, [:versioning, k], [])

      {k, value}
    end)
  end

  defp check_mutex_opts(%{patch: p, minor: m, major: ma, new_version: n, tag_current: c} = opts) do
    case {p, m, ma, n, c} do
      {true, false, false, nil, false} -> :ok
      {false, true, false, nil, false} -> :ok
      {false, false, true, nil, false} -> :ok
      {false, false, false, nil, true} -> :ok
      {false, false, false, _, false} -> :ok
      _ -> :error
    end
    |> case do
      :ok ->
        opts

      :error ->
        CLI.halt_error(
          "Options --patch, --minor, --major, --new-version and --tag-current are mutually exclusive"
        )
    end
  end
end
