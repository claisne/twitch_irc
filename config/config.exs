use Mix.Config

config :twitch_irc, irc_host: "irc.chat.twitch.tv"
config :twitch_irc, irc_port: 443

# secret.exs contains our tokens:
# config :twitch_irc, oauth_access_token: "TOKEN"
# config :twitch_irc, api_secret_token: "TOKEN"
# refer to the experiment to retrieve them
# and our IRC username
# config :twitch_irc, irc_name: ""
import_config "secret.exs"

import_config "#{Mix.env}.exs"
