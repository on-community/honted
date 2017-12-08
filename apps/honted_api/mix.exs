defmodule HonteD.API.Mixfile do
  use Mix.Project

  def project do
    [
      app: :honted_api,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
    ]
  end

  def application do
    [
      env: [
        rpc_port: 46_657, # tendermint node's rpc port
      ],
      extra_applications: [:logger],
      mod: {HonteD.API.Application, []}
    ]
  end

  defp deps do
    [
      {:tesla, "~>0.8.0"},
      {:plug, "~> 1.3"},
      {:poison, "~> 3.1"},
      {:bimap, "~> 0.1.1"},
      {:qex, "~> 0.3.4"},
      {:ex_unit_fixtures, "~> 0.3.1", only: [:test]},
      #
      {:honted_lib, in_umbrella: true},
    ]
  end
end
