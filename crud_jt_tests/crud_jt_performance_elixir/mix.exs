defmodule TestCrudJtPackage.MixProject do
  use Mix.Project

  def project do
    [
      app: :test_crud_jt_package,
      version: "0.1.0",
      elixir: "~> 1.12",
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

  def deps do
    [
      {:crudjt, "~> 1.0.0-beta.0"}
    ]
  end
end
