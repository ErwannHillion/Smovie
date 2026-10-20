defmodule SmovieWeb.ProfileTabsTest do
  use SmovieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Smovie.AccountsFixtures
  import Smovie.CatalogFixtures
  import Smovie.ReviewsFixtures

  alias Smovie.Accounts
  alias Smovie.Accounts.Scope
  alias Smovie.Library

  setup do
    user = user_fixture()
    scope = Scope.for_user(user)

    {:ok, user} =
      Accounts.update_user_profile(scope, user, %{
        "username" => "cinephile",
        "display_name" => "Cinephile"
      })

    film = movie_fixture(%{title: "Perfect Days", runtime: 124})
    serie = tv_show_fixture(%{title: "Severance"})
    Library.mark_watched(scope, film)
    Library.mark_watched(scope, serie)
    Library.rate_work(scope, film, 10)
    review_fixture(user, film)

    %{user: user, scope: scope, film: film, serie: serie}
  end

  test "l'apercu montre les chiffres cles", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/u/cinephile")

    assert html =~ "Films"
    assert html =~ "Notes"
    assert html =~ "Heures"
  end

  test "l'onglet films liste les films vus", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/u/cinephile?onglet=films")

    assert html =~ "Perfect Days"
  end

  test "l'onglet series liste les series", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/u/cinephile?onglet=series")

    assert html =~ "Severance"
    refute html =~ "Perfect Days"
  end

  test "l'onglet reviews liste les reviews", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/u/cinephile?onglet=reviews")

    assert html =~ "hors-champ"
  end

  test "un onglet inconnu retombe sur l'apercu", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/u/cinephile?onglet=nimportequoi")

    assert html =~ "Activite recente"
  end

  test "un profil prive ne montre aucun onglet", %{conn: conn, scope: scope, user: user} do
    Accounts.update_user_visibility(scope, user, %{"profile_visibility" => "private"})

    {:ok, _lv, html} = live(conn, ~p"/u/cinephile")

    assert html =~ "Ce profil est prive"
    refute html =~ "Perfect Days"
  end

  test "les reviews privees n'apparaissent pas pour un tiers", %{conn: conn, user: user} do
    review_fixture(user, movie_fixture(%{title: "Secrete"}), %{"visibility" => "private"})

    {:ok, _lv, html} = live(conn, ~p"/u/cinephile?onglet=reviews")

    refute html =~ "Secrete"
  end

  describe "onglet stats" do
    test "affiche la repartition des notes", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/u/cinephile?onglet=stats")

      assert html =~ "Repartition de vos notes"
      assert html =~ "moyenne 5,0"
    end

    test "un cran a une seule note reste visible", %{conn: conn} do
      # Sinon l'histogramme ment par omission.
      {:ok, _lv, html} = live(conn, ~p"/u/cinephile?onglet=stats")

      refute html =~ "height: 0px"
    end

    test "invite a noter quand il n'y a rien a montrer", %{conn: conn} do
      autre = user_fixture()

      {:ok, autre} =
        Accounts.update_user_profile(Scope.for_user(autre), autre, %{
          "username" => "debutant",
          "display_name" => "Debutant"
        })

      {:ok, _lv, html} = live(conn, ~p"/u/#{autre.username}?onglet=stats")

      assert html =~ "Notez quelques oeuvres"
    end
  end
end
