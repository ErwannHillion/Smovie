defmodule SmovieWeb.SearchLiveTest do
  use SmovieWeb.ConnCase, async: true

  import Mox
  import Phoenix.LiveViewTest
  import Smovie.AccountsFixtures
  import Smovie.CatalogFixtures
  import Smovie.TMDBPayloads

  alias Smovie.Accounts
  alias Smovie.Accounts.Scope
  alias Smovie.External.TMDBMock

  setup :verify_on_exit!

  setup do
    stub(TMDBMock, :search_multi, fn _term, _opts -> {:ok, search_multi([])} end)
    :ok
  end

  test "trouve une oeuvre du catalogue local", %{conn: conn} do
    movie_fixture(%{title: "Le Comte de Monte-Cristo"})

    {:ok, _lv, html} = live(conn, ~p"/recherche?q=monte-cristo")

    assert html =~ "Le Comte de Monte-Cristo"
    assert html =~ "Ouvrir"
  end

  test "trouve un membre", %{conn: conn} do
    user = user_fixture()

    {:ok, user} =
      Accounts.update_user_profile(Scope.for_user(user), user, %{
        "username" => "cinephile",
        "display_name" => "Cinephile"
      })

    {:ok, _lv, html} = live(conn, ~p"/recherche?q=cinephile")

    assert html =~ "@cinephile"
    assert user.username == "cinephile"
  end

  test "ne cherche pas sous trois caracteres", %{conn: conn} do
    movie_fixture(%{title: "Dune"})

    {:ok, _lv, html} = live(conn, ~p"/recherche?q=du")

    assert html =~ "au moins trois caracteres"
  end

  test "complete par TMDB quand le local ne rend pas grand-chose", %{conn: conn} do
    # La LiveView monte deux fois en test (rendu statique puis connexion) :
    # on stube plutot que de compter les appels.
    stub(TMDBMock, :search_multi, fn "severance", _opts ->
      {:ok, search_multi([search_tv()])}
    end)

    {:ok, _lv, html} = live(conn, ~p"/recherche?q=severance")

    assert html =~ "Severance"
    assert html =~ "pas encore dans Smovie"
    assert html =~ "Importer"
  end

  test "n'appelle pas TMDB quand le local suffit", %{conn: conn} do
    # Appeler TMDB systematiquement ajouterait une latence reseau a chaque
    # frappe.
    for n <- 1..6, do: movie_fixture(%{title: "Severance #{n}", original_title: "Severance"})

    stub(TMDBMock, :search_multi, fn _term, _opts ->
      raise "TMDB ne doit pas etre appele quand le catalogue local suffit"
    end)

    {:ok, _lv, html} = live(conn, ~p"/recherche?q=severance")

    refute html =~ "pas encore dans Smovie"
  end

  test "ne propose pas d'importer ce qui est deja la", %{conn: conn} do
    movie_fixture(%{title: "Dune, deuxième partie", tmdb_id: 693_134})

    stub(TMDBMock, :search_multi, fn _term, _opts ->
      {:ok, search_multi([search_movie()])}
    end)

    {:ok, _lv, html} = live(conn, ~p"/recherche?q=dune")

    refute html =~ "pas encore dans Smovie"
  end

  test "une panne TMDB ne vide pas la page", %{conn: conn} do
    movie_fixture(%{title: "Aftersun"})
    stub(TMDBMock, :search_multi, fn _term, _opts -> {:error, :request_failed} end)

    {:ok, _lv, html} = live(conn, ~p"/recherche?q=aftersun")

    assert html =~ "Aftersun"
  end

  test "importer une oeuvre mene a sa fiche", %{conn: conn} do
    stub(TMDBMock, :search_multi, fn _term, _opts ->
      {:ok, search_multi([search_movie()])}
    end)

    expect(TMDBMock, :get_movie, fn 693_134 -> {:ok, movie()} end)

    {:ok, lv, _html} = live(conn, ~p"/recherche?q=dune")

    assert {:error, {:live_redirect, %{to: path}}} =
             lv |> element(~s(button[phx-click="import"])) |> render_click()

    assert path =~ "/film/"
  end

  test "annonce l'absence de resultat", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/recherche?q=introuvable")

    assert html =~ "Aucun resultat"
  end
end
