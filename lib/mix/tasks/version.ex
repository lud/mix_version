defmodule Mix.Tasks.Version do
  alias MixVersion.CLI
  import MixVersion.Config
  use Mix.Task

  @readme "README.md"
  @external_resource @readme
  @readme_content @readme
                  |> File.read!()
                  |> String.split("<!-- doc-start -->")
                  |> Enum.at(1)
                  |> String.split("<!-- doc-end -->")
                  |> hd()

  @default_commit_msg "new version %s"
  @default_annotation "new version %s"
  @default_tag_prefix "v"
  @default_annotate true

  default_doc = fn _key, fallback ->
    "Defaults is pulled from `mix.exs` with fallback to `#{inspect(fallback)}`."
  end

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
      annotate: [
        type: :boolean,
        short: :a,
        doc: "Create an annotated git tag.",
        default: &__MODULE__.default_opt/1,
        default_doc: default_doc.(:annotate, @default_annotate)
      ],
      commit_msg: [
        type: :string,
        short: :c,
        doc: "Define the commit message, with all '%s' replaced by the new VSN.",
        default: &__MODULE__.default_opt/1,
        default_doc: default_doc.(:commit_msg, @default_commit_msg)
      ],
      annotation: [
        type: :string,
        short: :A,
        doc: "Define the tag annotation message, with all '%s' replaced by the new VSN.",
        default: &__MODULE__.default_opt/1,
        default_doc: default_doc.(:annotation, @default_annotation)
      ],
      tag_prefix: [
        type: :string,
        short: :x,
        doc: "Define the tag prefix.",
        default: &__MODULE__.default_opt/1,
        default_doc: default_doc.(:tag_prefix, @default_tag_prefix)
      ],
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

  #{@readme_content}

  #{@usage}
  """

  @shortdoc "Manages the version of an Elixir application"

  @stages [
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

  @doc false
  def run(argv) do
    CLI.with_safe_path(:mix_version, fn -> Mix.Task.run("loadpaths") end)

    command =
      CLI.parse_or_halt!(
        argv,
        @command
      )

    %{options: opts} = command

    env = %{
      opts: opts,
      hooks: collect_hooks(),
      current_vsn: current_vsn(),
      mixfile_path: Mix.Project.project_file(),
      cwd: File.cwd!()
    }

    case exec(env) do
      {:ok, _token} ->
        :ok

      {:error, reason} ->
        reason |> to_iodata() |> CLI.halt_error()

      {:stop, reason} ->
        reason |> to_iodata() |> CLI.warn()
        CLI.halt()
    end
  end

  @doc false
  def exec(env) do
    with :ok <- check_mutex_opts(env.opts) do
      run_stages(@stages, MixVersion.Token.new(env))
    end
  end

  @doc """
  Returns the default value for the given command line option.

  The value is read from the `:versioning` configuration of the current Mix
  project, with a fallback to the built-in default.
  """
  def default_opt(:commit_msg), do: default_from_project(:commit_msg, @default_commit_msg)
  def default_opt(:annotation), do: default_from_project(:annotation, @default_annotation)
  def default_opt(:tag_prefix), do: default_from_project(:tag_prefix, @default_tag_prefix)
  def default_opt(:annotate), do: default_from_project(:annotate, @default_annotate)

  defp default_from_project(key, default_default) do
    project = current_project()

    case project_get(project, [:versioning, key], :__not_configured__) do
      :__not_configured__ -> default_default
      value -> value
    end
  end

  defp current_vsn do
    _vsn = MixVersion.Config.project_get(:version)
  end

  defp run_stages(stages, token) do
    Enum.reduce_while(stages, {:ok, token}, fn stage, {:ok, token} ->
      case run_stage(stage, token) do
        {:ok, %MixVersion.Token{} = token} -> {:cont, {:ok, token}}
        {:halt, %MixVersion.Token{} = token} -> {:halt, {:ok, token}}
        {:error, _reason} = err -> {:halt, err}
        {:stop, _reason} = stop -> {:halt, stop}
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

  defp collect_hooks do
    project = current_project()

    keys = [:before_commit]

    Map.new(keys, fn k ->
      value = project_get(project, [:versioning, k], [])

      {k, value}
    end)
  end

  defp check_mutex_opts(%{patch: p, minor: m, major: ma, new_version: n, tag_current: c}) do
    check_mutex =
      case {p, m, ma, n, c} do
        {true, false, false, nil, false} -> :ok
        {false, true, false, nil, false} -> :ok
        {false, false, true, nil, false} -> :ok
        {false, false, false, nil, true} -> :ok
        {false, false, false, _, false} -> :ok
        _ -> :error
      end

    case check_mutex do
      :ok ->
        :ok

      :error ->
        {:error,
         "Options --patch, --minor, --major, --new-version and --tag-current are mutually exclusive"}
    end
  end
end
