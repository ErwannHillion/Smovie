defmodule SmovieWeb.Plugs.ContentSecurityPolicy do
  @moduledoc """
  Pose un en-tete `content-security-policy` et un nonce par requete.

  Le pipeline appelle `:put_secure_browser_headers` juste avant : ce plug le
  rappelle avec la CSP en en-tete supplementaire. L'appel est idempotent sur
  les en-tetes standards, et c'est la forme que sobelow reconnait comme une
  CSP effectivement posee.

  Le nonce evite le recours a `script-src 'unsafe-inline'`, qui reviendrait a
  poser une CSP sans la protection qu'on en attend : le seul script en ligne de
  l'application est celui qui applique le theme avant le premier rendu, et il
  doit rester en ligne pour ne pas provoquer de clignotement.

  Les affiches viennent de TMDB et ne sont pas rehebergees : `img-src` autorise
  explicitement le domaine d'images, et rien d'autre.
  """

  import Phoenix.Controller, only: [put_secure_browser_headers: 2]
  import Plug.Conn, only: [assign: 3]

  @image_host "https://image.tmdb.org"

  def init(opts), do: opts

  def call(conn, _opts) do
    nonce = generate_nonce()

    conn
    |> assign(:csp_nonce, nonce)
    |> put_secure_browser_headers(%{"content-security-policy" => policy(conn, nonce)})
  end

  defp generate_nonce do
    18 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end

  defp policy(conn, nonce) do
    Enum.join(
      [
        "default-src 'self'",
        "base-uri 'self'",
        "frame-ancestors 'none'",
        "object-src 'none'",
        "form-action 'self'",
        "img-src 'self' data: #{@image_host}",
        # Les polices sont hebergees par l'application : aucun domaine tiers.
        "font-src 'self'",
        # Tailwind pose des styles en ligne sur certains composants.
        "style-src 'self' 'unsafe-inline'",
        "script-src 'self' 'nonce-#{nonce}'",
        "connect-src 'self' #{websocket_sources(conn)}"
      ],
      "; "
    )
  end

  # LiveView ouvre une websocket sur le meme hote : en https elle passe en wss.
  defp websocket_sources(%Plug.Conn{scheme: :https, host: host}), do: "wss://#{host}"
  defp websocket_sources(%Plug.Conn{host: host}), do: "ws://#{host}:* wss://#{host}:*"
end
