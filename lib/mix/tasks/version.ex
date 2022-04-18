defmodule Mix.Tasks.Version do
  use Mix.Task

  @moduledoc """
  This module implements a mix task whose main purpose is to update the version
  number of an Elixir application, with extra steps such as committing a git tag
  and running system commands along the way.
  """

  @shortdoc "Manages the version of an Elixir application"

  import MixVersion.Cli

  def run(argv) do
    Mix.Task.run("app.config")

    {opts, _args} =
      command(__MODULE__)
      |> option(:major, :boolean,
        alias: :M,
        doc: "Bump to a new major version.",
        default: false
      )
      |> option(:minor, :boolean,
        alias: :m,
        doc: "Bump to a new minor version.",
        default: false
      )
      |> option(:patch, :boolean,
        alias: :p,
        doc: "Bump the patch version.",
        default: false
      )
      |> option(:new_version, :string,
        alias: :n,
        doc: "Sets the new version number.",
        default: nil
      )
      |> option(:annotate, :boolean,
        alias: :a,
        doc: "Create an annotated git tag."
      )
      |> option(:commit_msg, :string,
        alias: :c,
        doc: "Define the commit message, with all '%s' replaced by the new VSN."
      )
      |> option(:annotation, :string,
        alias: :A,
        doc: "Define the tag annotation message, with all '%s' replaced by the new VSN."
      )
      |> option(:tag_prefix, :string,
        alias: :x,
        doc: "Define the tag prefix."
      )
      |> parse(argv)

    opts =
      opts
      |> defaults_from_project()
      |> check_mutex_opts()

    token = MixVersion.Token.new(current_vsn(), opts)

    stages = [
      MixVersion.Stage.GetNextVsn,
      MixVersion.Stage.DetectGitCommand,
      MixVersion.Stage.FindGitRepo,
      MixVersion.Stage.CheckUnstaged,
      MixVersion.Stage.CheckGitTag,
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
          reason |> to_iodata() |> abort()

        {:stop, reason} ->
          reason |> to_iodata() |> warn()
          abort()
      end
    end)
  end

  defp run_stage(stage, token) do
    if stage.applies?(token) do
      stage.run(token)
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
    import MixVersion.Config
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

  defp check_mutex_opts(%{patch: p, minor: m, major: ma, new_version: n} = opts) do
    case {p, m, ma, n} do
      {true, false, false, nil} -> :ok
      {false, true, false, nil} -> :ok
      {false, false, true, nil} -> :ok
      {false, false, false, _} -> :ok
      _ -> :error
    end
    |> case do
      :ok ->
        opts

      :error ->
        abort("Options --patch, --minor, --major and --new-version are mutually exclusive")
    end
  end
end
