# Filename: config/dev.exs
import Config

# Configure your Phoenix endpoint for development
config :zzv_app, ZzvApp.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    # Add asset watchers if using webpack, esbuild, etc.
    node: ["node_modules/webpack/bin/webpack.js", "--mode", "development", "--watch-stdin", cd: Path.expand("../assets", __DIR__)]
  ]

# Watch static and templates for browser reloading
config :zzv_app, ZzvApp.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/zzv_app_web/(live|views)/.*(ex)$",
      ~r"lib/zzv_app_web/templates/.*(eex)$"
    ]
  ]

# Configure MongoDB for development
config :mongodb,
  url: System.get_env("DATABASE_URL") || "mongodb://root:password@mongodb:27017/zzv_dev",
  pool_size: 5

# Configure Kafka for development
config :kafka_ex,
  brokers: [{System.get_env("KAFKA_BROKER") || "kafka:9092", 9092}],
  consumer_group: "zzv-dev-group",
  disable_default_worker: false,
  sync_timeout: 3000

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Set a high stacktrace during development
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Enable dev routes for dashboard and testing tools
config :zzv_app, dev_routes: true
