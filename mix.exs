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
      description: "Provides structured parsing of data based on Typespecs.",
      dialyzer: dialyzer(),
      docs: docs()
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
      {:plug, "~> 1.7", optional: true},
      {:excoveralls, "~> 0.12", only: [:test]},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:credo, "~> 1.0", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.16", only: [:dev], runtime: false}
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

  defp dialyzer do
    [
      plt_local_path: "_build/plts",
      plt_add_apps: [:plug]
    ]
  end

  defp docs do
    [
      source_url: "https://github.com/visciang/dataspecs",
      extras: ["README.md"]
    ]
  end
end
