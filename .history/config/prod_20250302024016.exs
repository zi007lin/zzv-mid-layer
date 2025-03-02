# Filename: ./config/prod.exs
import Config

config :zzv_app, ZzvApp.Endpoint,
  url: [host: "zzv.io", port: 443, scheme: "https"],
  https: [
    port: 443,
    cipher_suite: :strong,
    certfile: "/app/priv/cert/zzv.io.crt",
    keyfile: "/app/priv/cert/zzv.io.key",
    transport_options: [socket_opts: [:inet6]]
  ],
  force_ssl: [hsts: true],
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true,
  root: ".",
  version: Application.spec(:zzv_app, :vsn)

# Kafka configuration for inter-instance communication
config :kafka_ex,
  brokers: [{System.get_env("KAFKA_BROKER") || "kafka.zzv.io:9092", 9092}],
  consumer_group: "zzv-instance-group",
  disable_default_worker: false,
  sync_timeout: 3000,
  max_restarts: 10,
  max_seconds: 60,
  ssl_options: [
    certfile: "/app/priv/cert/kafka-client.crt",
    keyfile: "/app/priv/cert/kafka-client.key",
    cacertfile: "/app/priv/cert/ca.crt"
  ]

# MongoDB configuration
config :mongodb,
  url: System.get_env("DATABASE_URL") || "mongodb://username:password@mongodb.zzv.io:27017/zzv_db",
  pool_size: 10,
  ssl: true,
  ssl_opts: [
    certfile: "/app/priv/cert/mongodb-client.crt",
    keyfile: "/app/priv/cert/mongodb-client.key",
    cacertfile: "/app/priv/cert/ca.crt",
    server_name_indication: 'mongodb.zzv.io'
  ]

# Logging configuration
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing
config :phoenix, :json_library, Jason

# Health check endpoint
config :zzv_app, ZzvApp.HealthCheck,
  enabled: true,
  path: "/health"

# Runtime configuration
import_config "prod.runtime.exs"
