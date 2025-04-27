defmodule NervesSystemAction.MixProject do
  use Mix.Project

  def project do
    [
      app: :nerve_system_action,
      version: "1.0.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: []
    ]
  end

  def application, do: []
end
