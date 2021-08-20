defmodule DataSpecs.Mixfile do
  use Mix.Project

  def project do
    [
      app: :dataspecs,
      name: "dataspecs",
      version: "0.0.1",
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: preferred_cli_env(),
      description: description(),
      package: package(),
      source_url: "https://github.com/visciang/dataspecs",
      dialyzer: [
        plt_file: {:no_warn, "deps/dialyzer.plt"}
      ]
    ]
  end

  defp description do
    "Provides structured parsing of data based on Typespecs."
  end

  defp package do
    [
      name: "dataspecs",
      licenses: ["MIT"],
      files: ["lib", "README.md", "LICENSE", "mix.exs"],
      maintainers: ["Giovanni Visciano"],
      links: %{"GitHub" => "https://github.com/visciang/dataspecs"}
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {DataSpecs.App, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:excoveralls, "~> 0.12", only: :test},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:credo, "~> 1.0", only: [:dev], runtime: false}
    ]
  end

  defp preferred_cli_env do
    [
      coveralls: :test,
      "coveralls.github": :test,
      "coveralls.detail": :test,
      "coveralls.post": :test,
      "coveralls.html": :test
    ]
  end
end
