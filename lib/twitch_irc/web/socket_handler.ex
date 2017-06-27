defmodule TwitchIrc.Web.SocketHandler do
  @behaviour :cowboy_websocket

  def init(req, state) do
    {:cowboy_websocket, req, state}
  end

  def broadcast(message) do
    text_message = Poison.encode!(message)
    Registry.dispatch(Registry.WebSocket, :online, fn entries ->
      for {pid, _} <- entries, do: send(pid, {:text_message, text_message})
    end)
  end

  def websocket_init(state) do
    Registry.register(Registry.WebSocket, :online, [])
    {:ok, state}
  end

  def websocket_handle(_frame, state) do
    {:ok, state}
  end

  def websocket_info({:text_message, message}, state) do
    {:reply, {:text, message}, state}
  end

  def websocket_info(_info, state) do
    {:ok, state}
  end
end
