defmodule Smovie.Library.WatchEntriesTest do
  use Smovie.DataCase, async: true

  import Smovie.AccountsFixtures
  import Smovie.CatalogFixtures

  alias Smovie.Accounts.Scope
  alias Smovie.Library
  alias Smovie.Library.WatchEntry
  alias Smovie.Repo

  setup do
    user = user_fixture()
    %{user: user, scope: Scope.for_user(user), movie: movie_fixture()}
  end

  describe "mark_watched/3" do
    test "cree une seance datee d'aujourd'hui", %{scope: scope, movie: movie} do
      assert {:ok, entry} = Library.mark_watched(scope, movie)

      assert entry.watched_on == Date.utc_today()
      refute entry.rewatch
    end

    test "un second marquage le meme jour n'ajoute rien", %{scope: scope, movie: movie} do
      # C'est presque toujours un double clic, pas deux visionnages.
      Library.mark_watched(scope, movie)
      Library.mark_watched(scope, movie)

      assert Repo.aggregate(WatchEntry, :count) == 1
    end

    test "un re-visionnage un autre jour s'ajoute a l'historique", %{scope: scope, movie: movie} do
      # C'est precisement ce que la table user_movies de l'ancienne version
      # perdait : elle n'avait qu'une ligne par (membre, oeuvre).
      Library.mark_watched(scope, movie, watched_on: ~D[2024-01-10])
      {:ok, second} = Library.mark_watched(scope, movie, watched_on: ~D[2025-06-02])

      assert Repo.aggregate(WatchEntry, :count) == 2
      assert second.rewatch
    end

    test "refuse une date dans le futur", %{scope: scope, movie: movie} do
      # Ce n'est pas un souvenir mais une faute de saisie, et elle fausserait
      # l'historique et les tendances.
      demain = Date.add(Date.utc_today(), 1)

      assert {:error, changeset} = Library.mark_watched(scope, movie, watched_on: demain)
      assert errors_on(changeset)[:watched_on]
    end

    test "met a jour le compteur de spectateurs de l'oeuvre", %{scope: scope, movie: movie} do
      Library.mark_watched(scope, movie)

      assert Repo.reload!(movie).smovie_watch_count == 1
    end

    test "deux seances d'un meme membre ne comptent qu'un spectateur", %{
      scope: scope,
      movie: movie
    } do
      Library.mark_watched(scope, movie, watched_on: ~D[2024-01-10])
      Library.mark_watched(scope, movie, watched_on: ~D[2025-06-02])

      assert Repo.reload!(movie).smovie_watch_count == 1
    end

    test "on marque un episode comme un film", %{scope: scope} do
      episode = tv_show_fixture() |> season_fixture() |> episode_fixture()

      assert {:ok, _entry} = Library.mark_watched(scope, episode)
      assert Library.watched?(scope, episode)
    end
  end

  describe "unmark_watched/3" do
    test "retire la seance la plus recente seulement", %{scope: scope, movie: movie} do
      # Effacer tout l'historique d'un clic serait irreversible et jamais ce
      # qu'on veut.
      Library.mark_watched(scope, movie, watched_on: ~D[2024-01-10])
      Library.mark_watched(scope, movie, watched_on: ~D[2025-06-02])

      assert :ok = Library.unmark_watched(scope, movie)

      assert [reste] = Repo.all(WatchEntry)
      assert reste.watched_on == ~D[2024-01-10]
    end

    test "retire une seance precise quand la date est donnee", %{scope: scope, movie: movie} do
      Library.mark_watched(scope, movie, watched_on: ~D[2024-01-10])
      Library.mark_watched(scope, movie, watched_on: ~D[2025-06-02])

      assert :ok = Library.unmark_watched(scope, movie, watched_on: ~D[2024-01-10])

      assert [reste] = Repo.all(WatchEntry)
      assert reste.watched_on == ~D[2025-06-02]
    end

    test "signale l'absence de seance", %{scope: scope, movie: movie} do
      assert Library.unmark_watched(scope, movie) == {:error, :not_watched}
    end
  end

  describe "lecture du journal" do
    test "watched?/2 est faux pour un visiteur", %{movie: movie} do
      refute Library.watched?(nil, movie)
    end

    test "list_watch_entries/2 part de la seance la plus recente", %{user: user, scope: scope} do
      a = movie_fixture(%{title: "A"})
      b = movie_fixture(%{title: "B"})
      Library.mark_watched(scope, a, watched_on: ~D[2024-01-10])
      Library.mark_watched(scope, b, watched_on: ~D[2025-06-02])

      assert [%{work: %{title: "B"}}, %{work: %{title: "A"}}] = Library.list_watch_entries(user)
    end

    test "list_watched_works/2 ne repete pas une oeuvre revue", %{user: user, scope: scope} do
      movie = movie_fixture()
      Library.mark_watched(scope, movie, watched_on: ~D[2024-01-10])
      Library.mark_watched(scope, movie, watched_on: ~D[2025-06-02])

      assert [vu] = Library.list_watched_works(user)
      assert vu.id == movie.id
    end

    test "watched_minutes/1 cumule les durees, episodes compris", %{user: user, scope: scope} do
      # Exclure les episodes donnerait un chiffre faux a qui regarde surtout
      # des series.
      film = movie_fixture(%{runtime: 120})
      episode = tv_show_fixture() |> season_fixture() |> episode_fixture(%{runtime: 48})

      Library.mark_watched(scope, film)
      Library.mark_watched(scope, episode)

      assert Library.watched_minutes(user) == 168
    end
  end

  describe "coups de coeur" do
    test "toggle_like/2 bascule", %{scope: scope, movie: movie} do
      assert {:ok, :liked} = Library.toggle_like(scope, movie)
      assert Library.liked?(scope, movie)

      assert {:ok, :unliked} = Library.toggle_like(scope, movie)
      refute Library.liked?(scope, movie)
    end

    test "un coup de coeur est independant de la note", %{scope: scope, movie: movie} do
      # On peut reconnaitre qu'un film est excellent sans l'aimer.
      Library.toggle_like(scope, movie)

      assert Library.liked?(scope, movie)
      assert Library.get_rating(scope, movie) == nil
    end

    test "liked?/2 est faux pour un visiteur", %{movie: movie} do
      refute Library.liked?(nil, movie)
    end
  end
end
