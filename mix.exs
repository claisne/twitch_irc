defmodule TwitchIrc.Mixfile do
  use Mix.Project

  def project do
    [app: :twitch_irc,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [extra_applications: [:logger, :exirc, :httpoison, :cowboy, :ranch],
     mod: {TwitchIrc, []}]
  end

  defp deps do
    [{:exirc, "~> 1.0"},
     {:httpoison, "~> 0.11"},
     {:poison, "~> 3.1.0"},
     {:cowboy, github: "ninenines/cowboy", tag: "2.0.0-pre.9"},
     {:credo, "~> 0.8", only: [:dev, :test], runtime: false}]
  end
end
