defmodule MixVersion.MixProject do
  use Mix.Project

  def project do
    [
      app: :mix_version,
      version: "0.0.1",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: []
    ]
  end

  defp deps do
    [
      {:inch_ex, "~> 2.0", only: :dev}
    ]
  end
end
