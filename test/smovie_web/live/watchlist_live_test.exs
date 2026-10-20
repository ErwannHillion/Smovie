defmodule SmovieWeb.WatchlistLiveTest do
  use SmovieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Smovie.AccountsFixtures
  import Smovie.CatalogFixtures

  alias Smovie.Accounts.Scope
  alias Smovie.Library

  setup %{conn: conn} do
    user = user_fixture()
    scope = Scope.for_user(user)
    film = movie_fixture(%{title: "Aftersun", runtime: 102, release_date: ~D[2022-11-18]})
    serie = tv_show_fixture(%{title: "Severance"})
    Library.add_to_watchlist(scope, film)
    Library.add_to_watchlist(scope, serie)

    %{conn: log_in_user(conn, user), user: user, scope: scope, film: film, serie: serie}
  end

  test "liste les oeuvres a voir", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/watchlist")

    assert html =~ "Aftersun"
    assert html =~ "Severance"
    assert html =~ "2 oeuvres"
  end

  test "annonce la duree totale", %{conn: conn} do
    # Savoir qu'on a trente films a voir ne dit pas combien de soirees cela
    # represente.
    {:ok, _lv, html} = live(conn, ~p"/watchlist")

    assert html =~ "de visionnage"
  end

  test "filtre par type", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/watchlist?type=tv_show")

    assert html =~ "Severance"
    refute html =~ "Aftersun"
  end

  test "trie par titre", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/watchlist?tri=title")

    assert String.split(html, "Aftersun") |> hd() |> String.length() <
             String.split(html, "Severance") |> hd() |> String.length()
  end

  test "un tri inconnu retombe sur le defaut", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/watchlist?tri=nimportequoi")

    assert html =~ "Aftersun"
  end

  test "retirer une oeuvre", %{conn: conn, scope: scope, film: film} do
    {:ok, lv, _html} = live(conn, ~p"/watchlist")

    lv |> element(~s(button[phx-value-slug="#{film.slug}"])) |> render_click()

    refute Library.in_watchlist?(scope, film)
  end

  test "distingue liste vide et filtre sans resultat", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/watchlist?type=movie")
    assert html =~ "Aftersun"

    autre = user_fixture()
    {:ok, _lv, vide} = build_conn() |> log_in_user(autre) |> live(~p"/watchlist")

    assert vide =~ "Votre liste a voir est vide"
  end
end
