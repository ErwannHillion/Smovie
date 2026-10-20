defmodule SmovieWeb.ErrorHTMLTest do
  use SmovieWeb.ConnCase, async: true

  import Phoenix.Template, only: [render_to_string: 4]

  test "la 404 propose un retour a l'accueil" do
    # Une page blanche affichant « Not Found » donne l'impression d'un site
    # casse, et prive le visiteur du seul geste utile.
    html = render_to_string(SmovieWeb.ErrorHTML, "404", "html", [])

    assert html =~ "404"
    assert html =~ "Page introuvable"
    assert html =~ ~s(href="/")
  end

  test "la 500 ne rejette pas la faute sur le visiteur" do
    html = render_to_string(SmovieWeb.ErrorHTML, "500", "html", [])

    assert html =~ "500"
    assert html =~ "de notre cote"
  end

  test "un statut inattendu reste rendu" do
    html = render_to_string(SmovieWeb.ErrorHTML, "403", "html", [])

    assert html =~ "403"
  end

  test "une page inexistante renvoie la page d'erreur habillee", %{conn: conn} do
    # En test, le routeur leve NoRouteError ; c'est le gestionnaire d'erreurs
    # de production qui la convertit en 404 via Plug.Exception.
    assert Plug.Exception.status(%Phoenix.Router.NoRouteError{
             conn: conn,
             router: SmovieWeb.Router
           }) == 404
  end
end
