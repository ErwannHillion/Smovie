# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :smovie, :scopes,
  user: [
    default: true,
    module: Smovie.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: Smovie.AccountsFixtures,
    test_login_helper: :register_and_log_in_user
  ]

config :smovie,
  ecto_repos: [Smovie.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :smovie, SmovieWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: SmovieWeb.ErrorHTML, json: SmovieWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Smovie.PubSub,
  live_view: [signing_salt: "O6QF1rjf"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :smovie, Smovie.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  smovie: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.0.9",
  smovie: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Francais par defaut, anglais disponible.
config :gettext, default_locale: "fr", locales: ~w(fr en)

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Oban — les files sont dimensionnees par ce qu'elles appellent, pas par le
# nombre de jobs attendus.
#
# `external_ratings` est volontairement a 2 : la file sert de limiteur de debit
# vers OMDb, dont le palier gratuit plafonne a 1000 requetes par jour.
config :smovie, Oban,
  repo: Smovie.Repo,
  engine: Oban.Engines.Basic,
  queues: [
    default: 10,
    catalog: 5,
    external_ratings: 2,
    notifications: 10
  ],
  plugins: [
    # Les jobs termines sont purges au bout d'une semaine.
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    {Oban.Plugins.Cron,
     crontab: [
       # 4 h du matin : TMDB a publie les sorties de la veille, et le trafic
       # est au plus bas.
       {"0 4 * * *", Smovie.Workers.SyncTrendingCatalogWorker}
     ]}
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
