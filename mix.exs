defmodule MixVersion.MixProject do
  use Mix.Project

  def project do
    [
      app: :mix_version,
      version: "2.3.0",
      description:
        "A simple tool to update an Elixir project version number and commit/tag the change.",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript(),
      docs: docs(),
      modkit: modkit(),
      versioning: versioning(),
      package: package(),
      source_url: "https://github.com/lud/mix_version",
      dialyzer: dialyzer()
    ]
  end

  def application do
    [
      extra_applications: [:mix]
    ]
  end

  defp escript do
    [
      main_module: MixVersion.Main,
      name: :xvsn,
      embed_elixir: true,
      path: "_build/escript/xvsn"
    ]
  end

  defp deps do
    [
      {:cli_mate, "~> 0.3", runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: :test, runtime: false}
    ]
  end

  def cli do
    [
      preferred_envs: [dialyzer: :test]
    ]
  end

  defp docs do
    [
      main: "Mix.Tasks.Version"
    ]
  end

  defp modkit do
    [
      mount: [
        {MixVersion, "lib/mix_version"},
        {Mix.Tasks, "lib/mix/tasks", flavor: :mix_task}
      ]
    ]
  end

  defp versioning do
    [
      annotate: true,
      before_commit: [
        fn vsn ->
          case System.cmd("git", ["cliff", "--tag", vsn, "-o", "CHANGELOG.md"],
                 stderr_to_stdout: true
               ) do
            {_, 0} -> IO.puts("Updated CHANGELOG.md with #{vsn}")
            {out, _} -> {:error, "Could not update CHANGELOG.md:\n\n #{out}"}
          end
        end,
        add: "CHANGELOG.md"
      ]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "Github" => "https://github.com/lud/mix_version",
        "Installation" => "https://github.com/lud/mix_version#installation",
        "Changelog" => "https://github.com/lud/mix_version/blob/master/CHANGELOG.md"
      }
    ]
  end

  defp dialyzer do
    [
      flags: [:unmatched_returns, :error_handling, :unknown, :extra_return],
      list_unused_filters: true,
      plt_add_deps: :app_tree,
      plt_add_apps: [:ex_unit, :mix],
      plt_local_path: "_build/plts"
    ]
  end
end
