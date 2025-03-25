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
      docs: docs(),
      modkit: modkit(),
      versioning: versioning(),
      package: package(),
      source_url: "https://github.com/lud/mix_version"
    ]
  end

  def application do
    [
      extra_applications: []
    ]
  end

  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:cli_mate, "~> 0.7", runtime: false}
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
end
