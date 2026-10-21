import Config

# -----------------------------------------------------------------------------
# Toutes les variables d'environnement se lisent ICI, et nulle part ailleurs.
# Le code applicatif passe par `Smovie.Config`.
# -----------------------------------------------------------------------------

# --- TMDB : catalogue et images. Obligatoire. ---
config :smovie, :tmdb,
  # TMDB propose deux formes : une cle v3 (parametre api_key) et un jeton de
  # lecture (en-tete Bearer). L'application accepte les deux et les distingue
  # elle-meme.
  access_token: System.get_env("TMDB_ACCESS_TOKEN"),
  api_key: System.get_env("TMDB_API_KEY"),
  base_url: System.get_env("TMDB_BASE_URL", "https://api.themoviedb.org/3"),
  image_base_url: System.get_env("TMDB_IMAGE_BASE_URL", "https://image.tmdb.org/t/p"),
  language: System.get_env("TMDB_LANGUAGE", "fr-FR"),
  region: System.get_env("TMDB_REGION", "FR")

# --- OMDb : notes presse. Optionnel, coupable sans redeploiement. ---
config :smovie, :omdb,
  api_key: System.get_env("OMDB_API_KEY"),
  base_url: System.get_env("OMDB_BASE_URL", "https://www.omdbapi.com"),
  enabled: System.get_env("OMDB_IS_ACTIVE", "false") == "true",
  daily_quota: String.to_integer(System.get_env("OMDB_DAILY_QUOTA", "1000"))

# --- Classements et notation ---
config :smovie, :trending,
  window_days: String.to_integer(System.get_env("TRENDING_WINDOW_DAYS", "7")),
  min_votes: String.to_integer(System.get_env("TRENDING_MIN_VOTES", "3"))

config :smovie, :ratings,
  prior_votes: String.to_integer(System.get_env("RATINGS_PRIOR_VOTES", "20"))

config :smovie, :reviews,
  popular_limit: String.to_integer(System.get_env("POPULAR_REVIEWS_LIMIT", "5")),
  min_body_length: String.to_integer(System.get_env("REVIEWS_MIN_BODY_LENGTH", "80"))

# --- Langues ---
config :smovie, :i18n,
  default_locale: System.get_env("DEFAULT_LOCALE", "fr"),
  locales: String.split(System.get_env("LOCALES", "fr,en"), ",", trim: true)

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/smovie start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :smovie, SmovieWeb.Endpoint, server: true
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :smovie, Smovie.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :smovie, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :smovie, SmovieWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :smovie, SmovieWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :smovie, SmovieWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  #     config :smovie, Smovie.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney, Req and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
