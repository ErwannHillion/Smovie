defmodule SmovieWeb.Plugs.ContentSecurityPolicyTest do
  use SmovieWeb.ConnCase, async: true

  describe "en-tete content-security-policy" do
    setup %{conn: conn}, do: %{conn: get(conn, ~p"/")}

    test "est pose sur les reponses du pipeline navigateur", %{conn: conn} do
      assert [policy] = get_resp_header(conn, "content-security-policy")
      assert policy =~ "default-src 'self'"
      assert policy =~ "object-src 'none'"
      assert policy =~ "frame-ancestors 'none'"
    end

    test "autorise les affiches TMDB et rien d'autre en image", %{conn: conn} do
      assert [policy] = get_resp_header(conn, "content-security-policy")
      assert policy =~ "img-src 'self' data: https://image.tmdb.org"
    end

    test "autorise la websocket LiveView", %{conn: conn} do
      assert [policy] = get_resp_header(conn, "content-security-policy")
      assert policy =~ "connect-src 'self' ws://"
    end

    test "n'autorise pas les scripts en ligne sans nonce", %{conn: conn} do
      assert [policy] = get_resp_header(conn, "content-security-policy")
      refute policy =~ "'unsafe-inline' 'nonce"
      refute policy =~ "script-src 'self' 'unsafe-inline'"
    end

    test "le nonce de l'en-tete est celui porte par le script de theme", %{conn: conn} do
      assert [policy] = get_resp_header(conn, "content-security-policy")
      assert [_, nonce] = Regex.run(~r/'nonce-([^']+)'/, policy)

      assert html_response(conn, 200) =~ ~s(<script nonce="#{nonce}">)
    end

    test "le nonce change a chaque requete", %{conn: conn} do
      [first] = get_resp_header(conn, "content-security-policy")
      [second] = build_conn() |> get(~p"/") |> get_resp_header("content-security-policy")

      refute first == second
    end
  end
end
