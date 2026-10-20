defmodule SmovieWeb.NavigationTest do
  use SmovieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "barre basse, mobile" do
    test "porte cinq entrees", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")

      assert html =~ "grid-cols-5"
      for label <- ~w(Accueil Chercher Messages Profil), do: assert(html =~ label)
    end

    test "est masquee a partir de md", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")

      assert html =~ "md:hidden"
    end

    test "reserve l'encoche", %{conn: conn} do
      # Sans cela, la derniere rangee passe sous la barre de geste iOS.
      {:ok, _lv, html} = live(conn, ~p"/")

      assert html =~ "tabbar-safe"
    end

    test "chaque entree fait au moins 44 px de haut", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")

      assert html =~ "min-h-11"
    end
  end

  describe "entree active" do
    test "l'accueil est actif sur la racine", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")

      assert current?(html, "/")
      refute current?(html, "/reviews")
    end

    test "la racine ne s'allume pas sur une autre page", %{conn: conn} do
      # Un simple prefixe rendrait "/" actif partout.
      {:ok, _lv, html} = live(conn, ~p"/reviews")

      refute current?(html, "/")
      assert current?(html, "/reviews")
    end
  end

  # Les attributs d'une balise ne sortent pas dans l'ordre du source : on
  # cherche un lien vers `path` qui porte aria-current="true", sans supposer
  # leur adjacence.
  defp current?(html, path) do
    html
    |> String.split("<a ")
    |> Enum.any?(fn tag ->
      String.contains?(tag, ~s(href="#{path}")) and
        String.contains?(tag, ~s(aria-current="true")) and
        String.starts_with?(tag |> String.split(">") |> hd(), ~s(href="#{path}"))
    end)
  end

  describe "etat de connexion" do
    test "propose connexion et inscription a un visiteur", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")

      assert html =~ "Connexion"
      assert html =~ "Inscription"
    end

    test "montre le compte et la deconnexion une fois connecte", %{conn: conn} do
      user = Smovie.AccountsFixtures.user_fixture()
      {:ok, _lv, html} = conn |> log_in_user(user) |> live(~p"/")

      assert html =~ "/users/log-out"
      assert html =~ "/users/settings"
    end
  end

  describe "destinations de la navigation" do
    test "les sections publiques s'affichent", %{conn: conn} do
      for path <- ["/reviews", "/recherche"] do
        assert {:ok, _lv, _html} = live(conn, path)
      end
    end

    test "les sections personnelles renvoient vers la connexion, pas vers une 404", %{conn: conn} do
      # Une watchlist est personnelle : un visiteur doit comprendre qu'il lui
      # manque un compte, pas croire que la page n'existe pas.
      for path <- ["/watchlist", "/messages"] do
        assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, path)
      end
    end

    test "une section personnelle s'affiche une fois connecte", %{conn: conn} do
      user = Smovie.AccountsFixtures.user_fixture()

      conn = log_in_user(conn, user)

      for path <- ["/watchlist", "/messages"] do
        assert {:ok, _lv, _html} = live(conn, path)
      end
    end
  end
end
