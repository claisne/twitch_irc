defmodule TwitchIrc.Irc do
  use GenServer

  require Logger

  alias TwitchIrc.Api
  alias TwitchIrc.Web.SocketHandler
  alias ExIrc.Client, as: IrcClient

  @host Application.get_env(:twitch_irc, :irc_host)
  @port Application.get_env(:twitch_irc, :irc_port)
  @pass "oauth:" <> Application.get_env(:twitch_irc, :oauth_access_token)
  @name Application.get_env(:twitch_irc, :irc_name)

  @kappa_regex Regex.compile!("Kappa")

  @update_timeout_seconds 15 * 1000
  @broadcast_timeout_seconds 1 * 1000

  defmodule State do
    defstruct channels: MapSet.new(),
              channels_data: Map.new(),
              channels_kappas: Map.new()

    def kappa_speed(%State{channels_kappas: channels_kappas, channels_data: channels_data}) do
      channels_kappas
      |> Enum.reject(fn {channel, channel_kappas} ->
          Enum.empty?(channel_kappas) || !Map.has_key?(channels_data, channel)
        end)
      |> Enum.map(fn {channel, channel_kappas} ->
          kappa_speed =
            channel_kappas
            |> Enum.reject(fn {_kappa_count, time, _message} ->
                  time < :os.system_time(:second) - 60
                end)
            |> Enum.map(fn {kappa_count, _time, _message} -> kappa_count end)
            |> Enum.sum

          channel_data = Map.fetch!(channels_data, channel)

          {_, _, last_kappa_message} = List.first(channel_kappas)

          %{kappa_speed: kappa_speed,
            channel_data: channel_data,
            last_kappa_message: last_kappa_message}
        end)
      |> Enum.sort_by(fn %{kappa_speed: kappa_speed} -> kappa_speed end, &>=/2)
      |> Enum.take(10)
    end
  end

  def start_link(state \\ %State{}) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def init(state) do
    IrcClient.add_handler(:irc_client, self())
    IrcClient.connect_ssl!(:irc_client, @host, @port)
    {:ok, state}
  end

  def handle_info({:connected, _server, _port}, state) do
    Logger.info "Connected"
    IrcClient.logon(:irc_client, @pass, @name, @name, @name)
    {:noreply, state}
  end

  def handle_info(:logged_in, state) do
    Logger.info "Logged in"

    send(self(), :update_channels)
    send(self(), :broadcast)

    {:noreply, state}
  end

  def handle_info(:update_channels, state) do
    state =
      case Api.get_top_channels(%{"limit" => 100}) do
        {:ok, top_channels_data} ->
          Logger.info "Requested top channels"
          update_channels(state, top_channels_data)
        :error ->
          Logger.warn "Failed to request top channels"
          state
      end

    schedule(:update_channels, @update_timeout_seconds)

    {:noreply, state}
  end

  def handle_info(:broadcast, state) do
    SocketHandler.broadcast(%{
      type: "KAPPA_SPEED",
      payload: State.kappa_speed(state),
    })

    schedule(:broadcast, @broadcast_timeout_seconds)

    {:noreply, state}
  end

  def handle_info({:joined, "#" <> channel}, state) do
    Logger.info "Joined #{channel}"

    channels = MapSet.put(state.channels, channel)
    channels_kappas = Map.put(state.channels_kappas, channel, [])

    {:noreply, %{state | channels: channels, channels_kappas: channels_kappas}}
  end

  def handle_info({:parted, "#" <> channel}, state) do
    Logger.info "Parted #{channel}"

    channels = MapSet.delete(state.channels, channel)
    channels_kappas = Map.delete(state.channels_kappas, channel)

    {:noreply, %{state | channels: channels, channels_kappas: channels_kappas}}
  end

  def handle_info({:received, message, _sender_info, "#" <> channel}, state) do
    kappa_captures = Regex.run(@kappa_regex, message)

    if is_nil(kappa_captures) do
      {:noreply, state}
    else
      channel_kappa =
        {Enum.count(kappa_captures),
         :os.system_time(:second),
         message}

      channels_kappas =
        Map.update!(state.channels_kappas, channel, fn channel_kappas ->
          [channel_kappa | channel_kappas]
          |> Enum.reject(fn {_kappa_count, time, _message} ->
               time < :os.system_time(:second) - 60
             end)
        end)

      {:noreply, %{state | channels_kappas: channels_kappas}}
    end
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  defp update_channels(state, top_channels_data) do
    top_channels =
      top_channels_data
      |> Enum.map(fn channel_data -> channel_data["name"] end)
      |> MapSet.new

    join_channels(top_channels, state.channels)
    part_channels(top_channels, state.channels)

    channels_data =
      top_channels_data
      |> Enum.map(fn channel_data ->
           Map.take(channel_data, ["name", "display_name", "game", "logo", "url"])
         end)
      |> Enum.map(fn channel_data ->
           {channel_data["name"], channel_data}
         end)
      |> Map.new

    %{state | channels_data: channels_data}
  end

  defp join_channels(top_channels, channels) do
    channels_to_join = MapSet.difference(top_channels, channels)

    Enum.each(channels_to_join, fn channel ->
      IrcClient.join(:irc_client, "#" <> channel)
    end)
  end

  defp part_channels(top_channels, channels) do
    channels_to_part = MapSet.difference(channels, top_channels)

    Enum.each(channels_to_part, fn channel ->
      IrcClient.part(:irc_client, "#" <> channel)
    end)
  end

  defp schedule(action, timeout_seconds) do
    Process.send_after(self(), action, timeout_seconds)
  end
end
