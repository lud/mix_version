defmodule MixVersion.MixProject do
  use Mix.Project

  def project do
    [
      app: :mix_version,
      version: "1.3.3",
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
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      main: "MixVersion"
    ]
  end

  defp modkit do
    [
      mount: [
        {MixVersion, "lib/mix_version"},
        {Mix.Tasks, {:mix_task, "lib/mix/tasks"}}
      ]
    ]
  end

  defp versioning do
    [
      annotate: true
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "Github" => "https://github.com/lud/mix_version",
        "Do not install as a dependency, but rather as a mix tool available globally" =>
          "https://github.com/lud/mix_version#installation",
        "CHANGELOG" => "https://github.com/lud/mix_version/blob/master/CHANGELOG.md"
      }
    ]
  end
end
