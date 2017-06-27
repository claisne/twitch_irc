defmodule TwitchIrc do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    start_cowboy()

    children = [
      worker(ExIrc.Client, [[], [name: :irc_client]]),
      worker(TwitchIrc.Irc, []),
      supervisor(Registry, [:duplicate, Registry.WebSocket]),
    ]

    opts = [strategy: :one_for_one, name: TwitchIrc.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def start_cowboy do
    port = String.to_integer(System.get_env("PORT") || "8081")
    dispatch = :cowboy_router.compile(routes())
    {:ok, _} =
      :cowboy.start_clear(:http_listener, 200, [port: port],
        %{env: %{dispatch: dispatch}})
  end

  def routes do
    [{:_, [{'/', TwitchIrc.Web.SocketHandler, []}]}]
  end
end
