import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :arke_server, ArkeServer.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "625whs3FT3Rqh7zUH9Htd6nMEuh+0E5u9f9Hg6UHsOnLGDPUzsLlR9NRXyHfXwDp",
  server: false

config :arke_postgres, ArkePostgres.Repo,
  database: "arke-repo-test",
  username: "postgres",
  password: System.get_env("DB_PASSWORD", "postgres"),
  hostname: System.get_env("DB_HOSTNAME", "localhost"),
  queue_target: 1000,
  pool: Ecto.Adapters.SQL.Sandbox

config :arke,
  persistence: %{
    arke_postgres: %{
      create: &ArkePostgres.create/2,
      #           get_all: &ArkePostgres.get_all/3,
      #           get_by: &ArkePostgres.get_by/3,
      update: &ArkePostgres.update/2,
      delete: &ArkePostgres.delete/2,
      execute_query: &ArkePostgres.Query.execute/2,
      get_parameters: &ArkePostgres.Query.get_parameters/0,
      create_project: &ArkePostgres.create_project/1,
      delete_project: &ArkePostgres.delete_project/1
    }
  }

config :arke_auth, ArkeAuth.Guardian,
  issuer: "arke_auth",
  secret_key: "5hyuhkszkm8jilkDxrXGTBz1z1KJk5dtVwLgLOXHQRsPEtxii3wFcAbx4Gtj1aQB",
  verify_issuer: true,
  token_ttl: %{"access" => {7, :days}, "refresh" => {30, :days}}
