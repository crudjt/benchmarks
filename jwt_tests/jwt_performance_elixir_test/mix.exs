defmodule JwtPerformanceElixirTest.MixProject do
  use Mix.Project

  def project do
    [
      app: :jwt_performance_elixir_test,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:joken, "~> 2.6"},
      {:jason, "~> 1.4"},
      {:msgpax, "~> 2.3"}
    ]
  end
end
