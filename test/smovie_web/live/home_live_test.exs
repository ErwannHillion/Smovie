defmodule SmovieWeb.HomeLiveTest do
  use SmovieWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Smovie.AccountsFixtures
  import Smovie.CatalogFixtures
  import Smovie.LibraryFixtures
  import Smovie.ReviewsFixtures

  alias Smovie.Accounts.Scope
  alias Smovie.Social
  alias Smovie.Trending

  describe "page vide" do
    test "accueille plutot que d'afficher des rangees vides", %{conn: conn} do
      # Six emplacements vides donnent l'impression d'une application en
      # panne, pas d'une application qu'on n'a pas encore rejointe.
      Trending.refresh()

      {:ok, _lv, html} = live(conn, ~p"/")

      assert html =~ "Le catalogue se remplit"
      refute html =~ "En tendance cette semaine"
    end
  end

  describe "page remplie" do
    setup do
      film = movie_fixture(%{title: "Dune, deuxième partie"})
      serie = tv_show_fixture(%{title: "Severance"})
      for _ <- 1..5, do: rate(user_fixture(), film, 9)
      for _ <- 1..5, do: rate(user_fixture(), serie, 9)
      Trending.refresh()

      %{film: film, serie: serie}
    end

    test "met en avant la premiere tendance", %{conn: conn, film: film} do
      {:ok, _lv, html} = live(conn, ~p"/")

      assert html =~ "Tendance n°1"
      assert html =~ film.title
    end

    test "liste les nouveautes et les tendances", %{conn: conn} do
      movie_fixture(%{title: "Sortie recente", release_date: Date.add(Date.utc_today(), -5)})

      {:ok, _lv, html} = live(conn, ~p"/")

      assert html =~ "Nouveautes"
      assert html =~ "Sortie recente"
      assert html =~ "En tendance cette semaine"
      assert html =~ "Series du moment"
    end

    test "les blocs sociaux sont absents pour un visiteur", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")

      refute html =~ "Populaire chez vos abonnements"
      refute html =~ "Activite de vos abonnements"
    end

    test "le bloc des abonnements apparait quand il a du contenu", %{conn: conn, serie: serie} do
      moi = user_fixture()
      scope = Scope.for_user(moi)
      amis = for _ <- 1..2, do: user_fixture()
      for ami <- amis, do: Social.follow(scope, ami)
      autre = movie_fixture(%{title: "Perfect Days"})
      for ami <- amis, do: rate(ami, autre, 9)

      {:ok, _lv, html} = conn |> log_in_user(moi) |> live(~p"/")

      assert html =~ "Populaire chez vos abonnements"
      assert html =~ "Perfect Days"
      assert html =~ serie.title
    end

    test "liste les reviews a la une", %{conn: conn, film: film} do
      review_fixture(user_fixture(), film)

      {:ok, _lv, html} = live(conn, ~p"/")

      assert html =~ "Reviews a la une"
      assert html =~ "hors-champ"
    end

    test "chaque affiche mene a sa fiche", %{conn: conn, film: film} do
      {:ok, _lv, html} = live(conn, ~p"/")

      assert html =~ ~s(href="/film/#{film.slug}")
    end

    test "une serie mene a sa fiche serie", %{conn: conn, serie: serie} do
      {:ok, _lv, html} = live(conn, ~p"/")

      assert html =~ ~s(href="/serie/#{serie.slug}")
    end
  end
end
