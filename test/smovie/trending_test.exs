defmodule Smovie.TrendingTest do
  use Smovie.DataCase, async: false

  import Smovie.AccountsFixtures
  import Smovie.CatalogFixtures
  import Smovie.LibraryFixtures

  alias Smovie.Accounts.Scope
  alias Smovie.Library
  alias Smovie.Social
  alias Smovie.Trending

  describe "vue materialisee" do
    test "classe une oeuvre bien notee devant une oeuvre peu notee" do
      populaire = movie_fixture(%{title: "Populaire"})
      discret = movie_fixture(%{title: "Discret"})

      for _ <- 1..10, do: rate(user_fixture(), populaire, 9)
      for _ <- 1..3, do: rate(user_fixture(), discret, 6)

      Trending.refresh()

      assert [premier | _] = Trending.list()
      assert premier.id == populaire.id
    end

    test "ecarte les oeuvres sous le seuil de signaux" do
      # Avec un seul signal, le classement ne serait que du bruit.
      solitaire = movie_fixture(%{title: "Solitaire"})
      rate(user_fixture(), solitaire, 10)

      Trending.refresh()

      refute solitaire.id in Enum.map(Trending.list(), & &1.id)
    end

    test "ne classe ni les saisons ni les episodes" do
      # Une saison en tendance sur l'accueil n'aurait pas de sens.
      episode = tv_show_fixture() |> season_fixture() |> episode_fixture()
      for _ <- 1..5, do: rate(user_fixture(), episode, 9)

      Trending.refresh()

      ids = Enum.map(Trending.list(kind: :movie) ++ Trending.list(kind: :tv_show), & &1.id)

      refute episode.id in ids
    end

    test "separe films et series" do
      film = movie_fixture()
      serie = tv_show_fixture()
      for _ <- 1..4, do: rate(user_fixture(), film, 9)
      for _ <- 1..4, do: rate(user_fixture(), serie, 9)

      Trending.refresh()

      assert Enum.map(Trending.list(kind: :movie), & &1.id) == [film.id]
      assert Enum.map(Trending.list(kind: :tv_show), & &1.id) == [serie.id]
    end

    test "headline/0 rend la premiere oeuvre" do
      film = movie_fixture()
      for _ <- 1..5, do: rate(user_fixture(), film, 9)

      Trending.refresh()

      assert Trending.headline().id == film.id
    end

    test "headline/0 rend nil sans tendance" do
      Trending.refresh()

      assert Trending.headline() == nil
    end
  end

  describe "popular_with_following/2" do
    setup do
      moi = user_fixture()
      scope = Scope.for_user(moi)
      amis = for _ <- 1..3, do: user_fixture()
      for ami <- amis, do: Social.follow(scope, ami)

      %{moi: moi, scope: scope, amis: amis, movie: movie_fixture()}
    end

    test "remonte ce que deux amis ont aime", %{scope: scope, amis: [a, b | _], movie: movie} do
      rate(a, movie, 9)
      rate(b, movie, 8)

      assert [found] = Trending.popular_with_following(scope)
      assert found.id == movie.id
    end

    test "exige deux avis concordants", %{scope: scope, amis: [a | _], movie: movie} do
      # Avec un seul, le bloc se remplirait de bruit.
      rate(a, movie, 10)

      assert Trending.popular_with_following(scope) == []
    end

    test "ignore les notes tiedes", %{scope: scope, amis: [a, b | _], movie: movie} do
      # On veut une recommandation, pas un simple visionnage.
      rate(a, movie, 5)
      rate(b, movie, 6)

      assert Trending.popular_with_following(scope) == []
    end

    test "exclut ce que le membre a deja note", %{scope: scope, amis: [a, b | _], movie: movie} do
      rate(a, movie, 9)
      rate(b, movie, 9)
      Library.rate_work(scope, movie, 4)

      assert Trending.popular_with_following(scope) == []
    end

    test "est vide sans abonnement" do
      assert Trending.popular_with_following(Scope.for_user(user_fixture())) == []
    end

    test "est vide pour un visiteur" do
      assert Trending.popular_with_following(nil) == []
    end
  end
end
