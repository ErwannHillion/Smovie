defmodule SmovieWeb.Hooks.LocaleTest do
  use SmovieWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  describe "locale dans les LiveViews" do
    test "une LiveView rend en francais par defaut", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      assert html =~ "Pas encore de compte"
    end

    test "une LiveView suit la locale de la session", %{conn: conn} do
      # Le plug pose la locale en session pendant la requete HTTP. Sans le
      # hook, la LiveView rendrait en francais malgre le cookie, et le bug ne
      # se verrait qu'apres la connexion websocket.
      {:ok, _lv, html} =
        conn
        |> put_req_cookie("locale", "en")
        |> live(~p"/users/log-in")

      assert html =~ "No account yet?"
      refute html =~ "Pas encore de compte"
    end

    test "le selecteur de langue renvoie sur la page courante", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      assert html =~ ~s(action="/locale/en")
      assert html =~ ~s(value="/users/log-in")
    end
  end
end
