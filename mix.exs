defmodule Schematic.MixProject do
  use Mix.Project

  def project do
    [
      app: :schematic,
      description: "Data validation and transformation",
      package: package(),
      version: "0.0.6",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      source_url: "https://github.com/mhanberg/schematic",
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      maintainers: ["Mitchell Hanberg"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/mhanberg/schematic"},
      files: ~w(lib CHANGELOG.md LICENSE mix.exs README.md .formatter.exs)
    ]
  end

  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end
