defmodule TwitchIrc.Api do
  use HTTPoison.Base

  @version "v5"
  @base_url "https://api.twitch.tv/kraken"

  @client_id Application.get_env(:twitch_irc, :api_secret_token)
  @accept_header_value "application/vnd.twitchtv.#{@version}+json"

  def process_url(url), do: @base_url <> url

  def process_request_headers(headers) do
    new_headers = [{"Accept", @accept_header_value},
                   {"Client-Id", @client_id}]
    new_headers ++ headers
  end

  def process_response_body(body), do: Poison.decode!(body)

  def get_top_streams(params \\ %{}) do
      case get("/streams", [], params: params) do
        {:ok, resp} -> Map.fetch(resp.body, "streams")
        {:error, _} -> :error
      end
  end

  def get_top_channels(params \\ %{}) do
    case get_top_streams(params) do
      {:ok, streams} ->
        channels = Enum.map(streams, fn stream -> Map.fetch!(stream, "channel") end)
        {:ok, channels}
      :error -> :error
    end
  end
end
