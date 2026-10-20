defmodule SmovieWeb.WorkLive.ShowTest do
  use SmovieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Smovie.AccountsFixtures
  import Smovie.CatalogFixtures
  import Smovie.LibraryFixtures

  alias Smovie.Accounts.Scope
  alias Smovie.Catalog
  alias Smovie.Catalog.Sync.OMDbMapper
  alias Smovie.Library
  alias Smovie.TMDBPayloads

  setup do
    %{movie: movie_fixture(), user: user_fixture()}
  end

  describe "affichage" do
    test "montre le titre, l'annee et le resume", %{conn: conn, movie: movie} do
      {:ok, _lv, html} = live(conn, ~p"/film/#{movie.slug}")

      assert html =~ movie.title
      assert html =~ "2024"
      assert html =~ "Paul Atréides"
    end

    test "montre les genres et le realisateur", %{conn: conn, movie: movie} do
      [sf] = Catalog.upsert_genres([%{tmdb_id: 878, name: "Science-Fiction"}])
      Catalog.put_work_genres(movie, [sf])
      Catalog.put_work_credits(movie, credits_for())

      {:ok, _lv, html} = live(conn, ~p"/film/#{movie.slug}")

      assert html =~ "Science-Fiction"
      assert html =~ "Denis Villeneuve"
    end

    test "un slug de serie ne s'ouvre pas en film", %{conn: conn} do
      show = tv_show_fixture()

      assert_error_sent 404, fn -> live(conn, ~p"/film/#{show.slug}") end
      assert {:ok, _lv, _html} = live(conn, ~p"/serie/#{show.slug}")
    end

    test "un slug inconnu sort en 404", %{conn: conn} do
      assert_error_sent 404, fn -> live(conn, ~p"/film/inconnu") end
    end
  end

  describe "les trois notes" do
    test "masque la note Smovie sous le seuil de votes", %{conn: conn, movie: movie, user: user} do
      # Sur une seule note, une moyenne est plus trompeuse que le nombre brut.
      rate(user, movie, 10)

      {:ok, lv, html} = live(conn, ~p"/film/#{movie.slug}")

      assert html =~ "1 note"
      assert lv |> element(~s([data-score="Smovie"])) |> render() =~ "—"
    end

    test "affiche la note Smovie au-dela du seuil", %{conn: conn, movie: movie} do
      for _ <- 1..50, do: rate(user_fixture(), movie, 9)

      {:ok, lv, html} = live(conn, ~p"/film/#{movie.slug}")

      assert html =~ "50 notes"

      # 50 notes a 4,5 etoiles, temperees par l'a priori bayesien : la fiche
      # affiche une note, et non plus un tiret.
      cellule = lv |> element(~s([data-score="Smovie"])) |> render()
      assert cellule =~ ~r/\d,\d/
      refute cellule =~ "—"
    end

    test "nomme la source reelle de la note presse", %{conn: conn, movie: movie} do
      movie
      |> Catalog.put_external_ratings(OMDbMapper.rating_attrs(TMDBPayloads.omdb(), movie.id))

      {:ok, _lv, html} = live(conn, ~p"/film/#{movie.slug}")

      assert html =~ "IMDb"
      assert html =~ "8,5"
    end

    test "affiche un tiret sans note presse", %{conn: conn, movie: movie} do
      {:ok, lv, _html} = live(conn, ~p"/film/#{movie.slug}")

      assert lv |> element(~s([data-score="Presse"])) |> render() =~ "—"
    end
  end

  describe "actions d'un membre connecte" do
    setup %{conn: conn, user: user} do
      %{conn: log_in_user(conn, user)}
    end

    test "noter met a jour la fiche sans rechargement", %{conn: conn, movie: movie, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/film/#{movie.slug}")

      html = lv |> element(~s(button[phx-value-value="8"])) |> render_click()

      assert html =~ "4,0"
      assert Library.get_rating(Scope.for_user(user), movie).value == 8
    end

    test "reposer la meme note la retire", %{conn: conn, movie: movie, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/film/#{movie.slug}")

      lv |> element(~s(button[phx-value-value="8"])) |> render_click()
      lv |> element(~s(button[phx-value-value="8"])) |> render_click()

      assert Library.get_rating(Scope.for_user(user), movie) == nil
    end

    test "marquer vu bascule l'etat", %{conn: conn, movie: movie, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/film/#{movie.slug}")

      lv |> element(~s(button[phx-click="toggle_watched"])) |> render_click()

      assert Library.watched?(Scope.for_user(user), movie)
    end

    test "ajouter a la watchlist bascule l'etat", %{conn: conn, movie: movie, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/film/#{movie.slug}")

      lv |> element(~s(button[phx-click="toggle_watchlist"])) |> render_click()

      assert Library.in_watchlist?(Scope.for_user(user), movie)
    end

    test "marquer vu retire de la watchlist", %{conn: conn, movie: movie, user: user} do
      scope = Scope.for_user(user)
      Library.add_to_watchlist(scope, movie)

      {:ok, lv, _html} = live(conn, ~p"/film/#{movie.slug}")
      lv |> element(~s(button[phx-click="toggle_watched"])) |> render_click()

      refute Library.in_watchlist?(scope, movie)
    end
  end

  describe "visiteur non connecte" do
    test "noter renvoie vers la connexion", %{conn: conn, movie: movie} do
      # Mieux vaut une invitation a se connecter qu'un geste ignore sans
      # explication.
      {:ok, lv, _html} = live(conn, ~p"/film/#{movie.slug}")

      assert {:error, {:live_redirect, %{to: "/users/log-in"}}} =
               lv |> element(~s(button[phx-value-value="8"])) |> render_click()
    end
  end

  describe "temps reel" do
    test "la note d'un autre membre met la fiche a jour", %{conn: conn, movie: movie} do
      {:ok, lv, _html} = live(conn, ~p"/film/#{movie.slug}")

      for _ <- 1..50, do: rate(user_fixture(), movie, 9)

      assert render(lv) =~ "50 notes"
    end
  end

  defp credits_for do
    [
      %{
        person: %{tmdb_id: 137_427, name: "Denis Villeneuve"},
        kind: :crew,
        job: "Director",
        department: "Directing",
        character: nil,
        display_order: nil
      }
    ]
  end
end
