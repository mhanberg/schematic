defmodule Schematic.MixProject do
  use Mix.Project

  def project do
    [
      app: :schematic,
      description: "Data validation and transformation",
      package: package(),
      version: "0.2.0",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      source_url: "https://github.com/mhanberg/schematic",
      deps: deps(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      maintainers: ["Mitchell Hanberg"],
      licenses: ["MIT"],
      links: %{
        GitHub: "https://github.com/mhanberg/schematic",
        Sponsor: "https://github.com/sponsors/mhanberg"
      },
      files: ~w(lib CHANGELOG.md LICENSE mix.exs README.md .formatter.exs)
    ]
  end

  defp deps do
    [
      {:telemetry, "~> 0.4 or ~> 1.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:stream_data, "~> 0.5.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs() do
    [
      main: "Schematic"
    ]
  end
end
