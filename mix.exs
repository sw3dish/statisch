defmodule Statisch.MixProject do
  use Mix.Project

  def project do
    [
      app: :statisch,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      escript: [main_module: Statisch],
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:earmark, "~> 1.4.37"},
      {:toml, "~> 0.7"},
      {:ecto, "~> 3.10.3"}
    ]
  end
end
