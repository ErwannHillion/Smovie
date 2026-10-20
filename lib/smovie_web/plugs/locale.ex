defmodule SmovieWeb.Plugs.Locale do
  @moduledoc """
  Resout la langue de la requete et la pose pour Gettext.

  Ordre de resolution, du plus explicite au plus devinable :

  1. la preference enregistree sur le compte — un choix delibere ;
  2. le cookie `locale` — un choix delibere d'un visiteur non connecte ;
  3. l'en-tete `accept-language` du navigateur ;
  4. la langue par defaut de l'application.

  La locale est aussi posee en session : les LiveViews n'ont pas acces a la
  connexion, et `SmovieWeb.Hooks.Locale` la relit au `mount`. Sans ce
  passage de relais, une LiveView rendrait en langue par defaut quel que soit
  le reglage.
  """

  import Plug.Conn

  alias Smovie.Config

  @cookie "locale"
  @cookie_max_age 365 * 24 * 60 * 60

  def init(opts), do: opts

  def call(conn, _opts) do
    locale = resolve(conn)

    Gettext.put_locale(SmovieWeb.Gettext, locale)

    conn
    |> assign(:locale, locale)
    |> put_session(:locale, locale)
  end

  @doc """
  Memorise un choix de langue dans le cookie, pour un an.

  Le cookie sert aux visiteurs non connectes, et de repli pour les autres.
  """
  def put_locale_cookie(conn, locale) do
    put_resp_cookie(conn, @cookie, locale, max_age: @cookie_max_age, same_site: "Lax")
  end

  defp resolve(conn) do
    user_locale(conn) || cookie_locale(conn) || header_locale(conn) || Config.default_locale()
  end

  defp user_locale(%Plug.Conn{assigns: %{current_scope: %{user: %{locale: locale}}}}),
    do: supported(locale)

  defp user_locale(_conn), do: nil

  defp cookie_locale(conn) do
    conn = fetch_cookies(conn)
    supported(conn.cookies[@cookie])
  end

  # `accept-language: fr-FR,fr;q=0.9,en;q=0.8` — on prend la premiere langue
  # servie par l'application, en ignorant la region et les poids.
  defp header_locale(conn) do
    conn
    |> get_req_header("accept-language")
    |> List.first()
    |> parse_accept_language()
  end

  defp parse_accept_language(nil), do: nil

  defp parse_accept_language(header) do
    header
    |> String.split(",")
    |> Enum.map(&language_tag/1)
    |> Enum.find_value(&supported/1)
  end

  defp language_tag(entry) do
    entry
    |> String.split(";")
    |> List.first()
    |> String.trim()
    |> String.split("-")
    |> List.first()
    |> String.downcase()
  end

  defp supported(locale) do
    if Config.supported_locale?(locale), do: locale
  end
end
