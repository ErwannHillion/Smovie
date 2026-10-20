defmodule Smovie.Library.WatchlistTest do
  use Smovie.DataCase, async: true

  import Smovie.AccountsFixtures
  import Smovie.CatalogFixtures

  alias Smovie.Accounts.Scope
  alias Smovie.Catalog
  alias Smovie.Library

  setup do
    user = user_fixture()
    %{user: user, scope: Scope.for_user(user), movie: movie_fixture()}
  end

  describe "add_to_watchlist/3" do
    test "ajoute un film", %{scope: scope, user: user, movie: movie} do
      assert {:ok, _item} = Library.add_to_watchlist(scope, movie)
      assert Library.in_watchlist?(scope, movie)
      assert Library.watchlist_count(user) == 1
    end

    test "un second ajout ne cree pas de doublon", %{scope: scope, user: user, movie: movie} do
      Library.add_to_watchlist(scope, movie)
      Library.add_to_watchlist(scope, movie)

      assert Library.watchlist_count(user) == 1
    end

    test "refuse une saison et un episode", %{scope: scope} do
      # On ne met pas un episode « a voir », on reprend une serie la ou on l'a
      # laissee.
      season = tv_show_fixture() |> season_fixture()
      episode = episode_fixture(season)

      assert Library.add_to_watchlist(scope, season) == {:error, :not_watchlistable}
      assert Library.add_to_watchlist(scope, episode) == {:error, :not_watchlistable}
    end

    test "accepte une serie", %{scope: scope} do
      assert {:ok, _item} = Library.add_to_watchlist(scope, tv_show_fixture())
    end

    test "accepte une note personnelle", %{scope: scope, movie: movie} do
      assert {:ok, item} = Library.add_to_watchlist(scope, movie, %{note: "Conseille par Lea"})
      assert item.note == "Conseille par Lea"
    end
  end

  describe "retrait" do
    test "remove_from_watchlist/2 signale l'absence", %{scope: scope, movie: movie} do
      assert Library.remove_from_watchlist(scope, movie) == {:error, :not_in_watchlist}
    end

    test "toggle_watchlist/2 bascule", %{scope: scope, movie: movie} do
      assert {:ok, :added} = Library.toggle_watchlist(scope, movie)
      assert {:ok, :removed} = Library.toggle_watchlist(scope, movie)

      refute Library.in_watchlist?(scope, movie)
    end

    test "marquer vu retire de la liste a voir", %{scope: scope, movie: movie} do
      # L'oeuvre n'est plus a voir : l'y laisser obligerait a un second geste.
      Library.add_to_watchlist(scope, movie)
      Library.mark_watched(scope, movie)

      refute Library.in_watchlist?(scope, movie)
    end

    test "marquer vu une oeuvre absente de la liste ne leve pas", %{scope: scope, movie: movie} do
      assert {:ok, _entry} = Library.mark_watched(scope, movie)
    end
  end

  describe "tri" do
    setup %{scope: scope} do
      ancien = movie_fixture(%{title: "Ancien", release_date: ~D[1999-03-31], runtime: 180})
      recent = movie_fixture(%{title: "Zephyr", release_date: ~D[2024-06-01], runtime: 90})

      Library.add_to_watchlist(scope, ancien)
      Library.add_to_watchlist(scope, recent)

      %{ancien: ancien, recent: recent}
    end

    test "par date d'ajout, du plus recent", %{user: user, recent: recent} do
      assert [premier | _] = Library.list_watchlist(user)
      assert premier.id == recent.id
    end

    test "par sortie", %{user: user, recent: recent} do
      assert [premier | _] = Library.list_watchlist(user, sort: :release)
      assert premier.id == recent.id
    end

    test "par duree croissante", %{user: user, recent: recent} do
      assert [premier | _] = Library.list_watchlist(user, sort: :runtime)
      assert premier.id == recent.id
    end

    test "par titre", %{user: user, ancien: ancien} do
      assert [premier | _] = Library.list_watchlist(user, sort: :title)
      assert premier.id == ancien.id
    end

    test "un tri inconnu retombe sur la date d'ajout", %{user: user, recent: recent} do
      # L'ordre vient de l'URL, donc de l'exterieur : lever serait offrir une
      # 500 a qui modifie un parametre.
      assert [premier | _] = Library.list_watchlist(user, sort: :n_importe_quoi)
      assert premier.id == recent.id
    end
  end

  describe "filtres" do
    test "par nature", %{scope: scope, user: user, movie: movie} do
      show = tv_show_fixture()
      Library.add_to_watchlist(scope, movie)
      Library.add_to_watchlist(scope, show)

      assert [found] = Library.list_watchlist(user, kind: :tv_show)
      assert found.id == show.id
    end

    test "par genre", %{scope: scope, user: user, movie: movie} do
      autre = movie_fixture(%{title: "Sans genre"})
      [sf] = Catalog.upsert_genres([%{tmdb_id: 878, name: "Science-Fiction"}])
      Catalog.put_work_genres(movie, [sf])

      Library.add_to_watchlist(scope, movie)
      Library.add_to_watchlist(scope, autre)

      assert [found] = Library.list_watchlist(user, genre_id: sf.id)
      assert found.id == movie.id
    end
  end

  describe "totaux" do
    test "watchlist_minutes/1 cumule les durees", %{scope: scope, user: user} do
      Library.add_to_watchlist(scope, movie_fixture(%{runtime: 120}))
      Library.add_to_watchlist(scope, movie_fixture(%{runtime: 90, title: "B"}))

      assert Library.watchlist_minutes(user) == 210
    end

    test "une liste vide ne rend pas nil", %{user: user} do
      assert Library.watchlist_minutes(user) == 0
      assert Library.watchlist_count(user) == 0
    end
  end
end
