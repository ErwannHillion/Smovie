defmodule Smovie.Catalog.ExternalRatingsTest do
  use Smovie.DataCase, async: true

  import Mox
  import Smovie.CatalogFixtures
  import Smovie.TMDBPayloads

  alias Smovie.Catalog
  alias Smovie.Catalog.ExternalRating
  alias Smovie.Catalog.Sync.OMDbMapper
  alias Smovie.External.OMDbMock
  alias Smovie.Workers.FetchExternalRatingsWorker, as: Worker

  use Oban.Testing, repo: Smovie.Repo

  setup :verify_on_exit!

  setup do
    %{movie: movie_fixture(%{imdb_id: "tt15239678"})}
  end

  describe "put_external_ratings/2" do
    test "enregistre les notes et les met a jour sans doublon", %{movie: movie} do
      Catalog.put_external_ratings(movie, OMDbMapper.rating_attrs(omdb(), movie.id))

      Catalog.put_external_ratings(
        movie,
        OMDbMapper.rating_attrs(omdb(%{"imdbRating" => "8.7"}), movie.id)
      )

      ratings = Catalog.external_ratings(movie)

      assert map_size(ratings) == 3
      assert Decimal.equal?(ratings[:imdb].score, Decimal.new("8.7"))
    end

    test "la base refuse une echelle inattendue", %{movie: movie} do
      attrs = %{
        work_id: movie.id,
        source: :imdb,
        score: Decimal.new("5"),
        scale: 20,
        fetched_at: DateTime.utc_now(:second)
      }

      assert {:error, changeset} =
               %ExternalRating{} |> ExternalRating.changeset(attrs) |> Smovie.Repo.insert()

      assert errors_on(changeset)[:scale]
    end
  end

  describe "press_rating/1" do
    test "privilegie IMDb", %{movie: movie} do
      Catalog.put_external_ratings(movie, OMDbMapper.rating_attrs(omdb(), movie.id))

      assert {"IMDb", 8.5} = Catalog.press_rating(movie)
    end

    test "retombe sur Metacritic puis sur Rotten Tomatoes", %{movie: movie} do
      Catalog.put_external_ratings(
        movie,
        OMDbMapper.rating_attrs(omdb(%{"imdbRating" => "N/A"}), movie.id)
      )

      assert {"Metacritic", 7.9} = Catalog.press_rating(movie)
    end

    test "ne rend rien sans note presse", %{movie: movie} do
      assert Catalog.press_rating(movie) == nil
    end

    test "nomme toujours la source reelle", %{movie: movie} do
      # Afficher une note TMDB sous le mot « presse » serait faux : c'est la
      # raison d'etre du tuple.
      Catalog.put_external_ratings(movie, [
        %{
          source: :tmdb,
          score: Decimal.new("8.2"),
          scale: 10,
          fetched_at: DateTime.utc_now(:second)
        }
      ])

      assert Catalog.press_rating(movie) == nil
    end
  end

  describe "press_rating_stale?/1" do
    test "est faux sans identifiant IMDb" do
      assert Catalog.press_rating_stale?(movie_fixture(%{imdb_id: nil})) == false
    end

    test "est vrai quand aucune note n'a ete recuperee", %{movie: movie} do
      assert Catalog.press_rating_stale?(movie)
    end

    test "est faux juste apres une recuperation", %{movie: movie} do
      Catalog.put_external_ratings(movie, OMDbMapper.rating_attrs(omdb(), movie.id))

      refute Catalog.press_rating_stale?(movie)
    end
  end

  describe "FetchExternalRatingsWorker" do
    test "enregistre les notes de l'oeuvre", %{movie: movie} do
      expect(OMDbMock, :get_by_imdb_id, fn "tt15239678" -> {:ok, omdb()} end)

      assert :ok = perform_job(Worker, %{"work_id" => movie.id})
      assert map_size(Catalog.external_ratings(movie)) == 3
    end

    test "annule sur une oeuvre supprimee entre la mise en file et l'execution" do
      movie = movie_fixture(%{imdb_id: "tt1"})
      Smovie.Repo.delete!(movie)

      assert {:cancel, :work_deleted} = perform_job(Worker, %{"work_id" => movie.id})
    end

    test "annule sur une oeuvre sans identifiant IMDb" do
      movie = movie_fixture(%{imdb_id: nil})

      assert {:cancel, :no_imdb_id} = perform_job(Worker, %{"work_id" => movie.id})
    end

    test "annule quand OMDb est coupe", %{movie: movie} do
      expect(OMDbMock, :get_by_imdb_id, fn _ -> {:error, :disabled} end)

      assert {:cancel, :disabled} = perform_job(Worker, %{"work_id" => movie.id})
    end

    test "repousse au lendemain quand le quota est atteint", %{movie: movie} do
      # Mille requetes par jour : un echec ferait perdre le job, un report le
      # conserve.
      expect(OMDbMock, :get_by_imdb_id, fn _ -> {:error, :quota_exceeded} end)

      assert {:snooze, seconds} = perform_job(Worker, %{"work_id" => movie.id})
      assert seconds > 0
    end

    test "reessaie sur une erreur transitoire", %{movie: movie} do
      expect(OMDbMock, :get_by_imdb_id, fn _ -> {:error, :request_failed} end)

      assert {:error, :request_failed} = perform_job(Worker, %{"work_id" => movie.id})
    end

    test "enqueue/1 ne met rien en file sans identifiant IMDb" do
      assert Worker.enqueue(movie_fixture(%{imdb_id: nil})) == {:ok, :no_imdb_id}
      refute_enqueued(worker: Worker)
    end

    test "enqueue/1 met l'oeuvre en file", %{movie: movie} do
      assert {:ok, _job} = Worker.enqueue(movie)
      assert_enqueued(worker: Worker, args: %{work_id: movie.id})
    end
  end
end
