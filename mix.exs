defmodule Arke.MixProject do
  use Mix.Project

  def project do
    [
      app: :arke,
      name: "Arke",
      version: "0.1.2",
      build_path: "./_build",
      deps_path: "./deps",
      lockfile: "./mix.lock",
      elixir: "~> 1.13",
      dialyzer: [plt_add_apps: ~w[eex]a],
      description: description(),
      package: package(),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      aliases: aliases(),
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [warnings_as_errors: false]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Arke.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:typed_struct, "~> 0.2.1"},
      {:uuid, "~> 1.1"},
      {:ex_doc, "~> 0.28", only: :dev, runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.10", only: :test},
      {:timex, "~> 3.7.11"},
      {:google_api_storage, "~> 0.34.0"},
      {:goth, "~> 1.3.0"},
      {:httpoison, "~> 2.0"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
      # {:sibling_app_in_umbrella, in_umbrella: true}
    ]
  end

  defp aliases do
    [
      test: [
        "ecto.drop",
        "ecto.create --quiet",
        "ecto.migrate --migrations-path apps/arke_postgres/test/support/migrations",
        "test"
      ],
      "test.ci": [
        "ecto.create --quiet",
        "ecto.migrate --migrations-path apps/arke_postgres/test/support/migrations",
        "test"
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp description() do
    "Arke"
  end

  defp package() do
    [
      # This option is only needed when you don't want to use the OTP application name
      name: "arke",
      # These are the default files included in the package
      licenses: ["Apache-2.0"],
      links: %{}
    ]
  end
end
