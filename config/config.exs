import Config

config :logger, level: :info

import_config "#{config_env()}.exs"
