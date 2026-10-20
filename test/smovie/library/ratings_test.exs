defmodule Smovie.Library.RatingsTest do
  use Smovie.DataCase, async: true

  import Smovie.AccountsFixtures
  import Smovie.CatalogFixtures
  import Smovie.LibraryFixtures

  alias Smovie.Accounts.Scope
  alias Smovie.Library
  alias Smovie.Library.Rating
  alias Smovie.Repo

  setup do
    user = user_fixture()
    %{user: user, scope: Scope.for_user(user), movie: movie_fixture()}
  end

  describe "conversion" do
    test "les demi-etoiles se lisent sur 5" do
      assert Rating.to_stars(1) == 0.5
      assert Rating.to_stars(7) == 3.5
      assert Rating.to_stars(10) == 5.0
    end

    test "et inversement" do
      assert Rating.from_stars(3.5) == 7
      assert Rating.from_stars(5) == 10
    end
  end

  describe "rate_work/3" do
    test "pose une note", %{scope: scope, movie: movie} do
      assert {:ok, rating} = Library.rate_work(scope, movie, 7)
      assert rating.value == 7
      assert rating.rated_at
    end

    test "remplace la note precedente sans doublon", %{scope: scope, movie: movie} do
      {:ok, _} = Library.rate_work(scope, movie, 7)
      {:ok, rating} = Library.rate_work(scope, movie, 9)

      assert rating.value == 9
      assert Repo.aggregate(Rating, :count) == 1
    end

    test "refuse une valeur hors des dix crans", %{scope: scope, movie: movie} do
      for invalide <- [0, 11, -1] do
        assert {:error, changeset} = Library.rate_work(scope, movie, invalide)
        assert errors_on(changeset)[:value]
      end
    end

    test "la base refuse une valeur hors bornes meme sans changeset", %{user: user, movie: movie} do
      assert_raise Postgrex.Error, ~r/ratings_value_range/, fn ->
        Repo.insert_all("ratings", [
          %{
            user_id: user.id,
            work_id: movie.id,
            value: 42,
            rated_at: DateTime.utc_now(:second),
            inserted_at: DateTime.utc_now(:second),
            updated_at: DateTime.utc_now(:second)
          }
        ])
      end
    end

    test "on peut noter un episode comme un film", %{scope: scope} do
      # C'est tout l'interet de la table works unifiee : le meme code.
      episode = tv_show_fixture() |> season_fixture() |> episode_fixture()

      assert {:ok, rating} = Library.rate_work(scope, episode, 10)
      assert rating.work_id == episode.id
    end

    test "noter un episode n'oblige pas a noter la serie", %{scope: scope} do
      show = tv_show_fixture()
      episode = show |> season_fixture() |> episode_fixture()

      Library.rate_work(scope, episode, 9)

      assert Library.get_rating(scope, show) == nil
    end
  end

  describe "moyenne bayesienne" do
    test "une note unique ne place pas l'oeuvre en tete", %{scope: scope, movie: movie} do
      # Une moyenne brute afficherait 10 sur 10 : sur une plateforme jeune, ce
      # serait du bruit en haut de tous les classements.
      {:ok, _} = Library.rate_work(scope, movie, 10)

      movie = Repo.reload!(movie)

      assert movie.smovie_rating_count == 1
      assert Decimal.lt?(movie.smovie_rating_avg, Decimal.new("8"))
    end

    test "la vraie moyenne s'impose quand les notes s'accumulent", %{movie: movie} do
      for _ <- 1..200, do: rate(user_fixture(), movie, 10)

      movie = Repo.reload!(movie)

      assert movie.smovie_rating_count == 200
      assert Decimal.gt?(movie.smovie_rating_avg, Decimal.new("9.5"))
    end

    test "retirer la derniere note remet la moyenne a nil", %{scope: scope, movie: movie} do
      {:ok, _} = Library.rate_work(scope, movie, 8)
      :ok = Library.unrate_work(scope, movie)

      movie = Repo.reload!(movie)

      assert movie.smovie_rating_count == 0
      assert movie.smovie_rating_avg == nil
    end

    test "les notes d'une oeuvre n'affectent pas une autre", %{scope: scope, movie: movie} do
      autre = movie_fixture(%{title: "Un autre"})
      {:ok, _} = Library.rate_work(scope, movie, 10)

      assert Repo.reload!(autre).smovie_rating_count == 0
    end
  end

  describe "unrate_work/2" do
    test "signale l'absence de note", %{scope: scope, movie: movie} do
      assert Library.unrate_work(scope, movie) == {:error, :not_rated}
    end
  end

  describe "toggle_rating/3" do
    test "reposer la meme note la retire", %{scope: scope, movie: movie} do
      # Un geste unique pour poser, corriger et retirer.
      {:ok, _} = Library.toggle_rating(scope, movie, 7)
      assert Library.toggle_rating(scope, movie, 7) == :ok

      assert Library.get_rating(scope, movie) == nil
    end

    test "une autre valeur corrige la note", %{scope: scope, movie: movie} do
      {:ok, _} = Library.toggle_rating(scope, movie, 7)
      {:ok, rating} = Library.toggle_rating(scope, movie, 9)

      assert rating.value == 9
    end
  end

  describe "lecture" do
    test "get_rating/2 renvoie nil pour un visiteur", %{movie: movie} do
      assert Library.get_rating(nil, movie) == nil
    end

    test "ratings_by_work_id/2 charge toute une saison en une requete", %{scope: scope} do
      season = tv_show_fixture() |> season_fixture()
      episodes = for n <- 1..3, do: episode_fixture(season, %{episode_number: n, title: "E#{n}"})

      Library.rate_work(scope, hd(episodes), 8)

      notes = Library.ratings_by_work_id(scope, episodes)

      assert map_size(notes) == 1
      assert notes[hd(episodes).id].value == 8
    end

    test "rating_histogram/1 presente les dix crans, zeros compris", %{user: user, movie: movie} do
      rate(user, movie, 7)

      histogramme = Library.rating_histogram(user)

      assert map_size(histogramme) == 10
      assert histogramme[7] == 1
      assert histogramme[1] == 0
    end
  end

  describe "moyenne de la plateforme" do
    test "part d'une valeur par defaut" do
      assert Decimal.equal?(Library.global_average(), Decimal.new("6.80"))
    end

    test "se rafraichit depuis les notes reelles", %{movie: movie} do
      for value <- [8, 8, 10], do: rate(user_fixture(), movie, value)

      {:ok, average} = Library.refresh_global_average()

      assert Decimal.equal?(average, Decimal.new("8.67"))
    end

    test "retombe sur la valeur par defaut sans aucune note" do
      {:ok, average} = Library.refresh_global_average()

      assert Decimal.equal?(average, Decimal.new("6.80"))
    end
  end

  describe "diffusion temps reel" do
    test "une note annonce la nouvelle moyenne", %{scope: scope, movie: movie} do
      Phoenix.PubSub.subscribe(Smovie.PubSub, Library.rating_topic(movie))

      Library.rate_work(scope, movie, 8)

      assert_receive {:rating_updated, %{smovie_rating_count: 1}}
    end
  end
end
