defmodule Subapp.MixProject do
  use Mix.Project

  def project do
    [
      app: :subapp,
      version: "0.1.0",
      elixir: "~> 1.10",
      versioning: versioning(),
      deps: deps()
    ]
  end

  def application do
    [extra_applications: []]
  end

  # Tests drive this through `Subapp.configure_versioning/2` instead of
  # rewriting this mixfile.
  defp versioning do
    {config, _bindings} = Code.eval_file(Path.join(__DIR__, "versioning.exs"))
    config
  end

  defp deps do
    [{:mix_version, path: System.fetch_env!("MIX_VERSION_DEP_ROOT")}]
  end
end
