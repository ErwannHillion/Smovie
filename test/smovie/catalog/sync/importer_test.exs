defmodule Smovie.Catalog.Sync.ImporterTest do
  use Smovie.DataCase, async: true

  import Mox
  import Smovie.CatalogFixtures
  import Smovie.TMDBPayloads

  alias Smovie.Catalog
  alias Smovie.Catalog.Sync.Importer
  alias Smovie.External.TMDBMock

  setup :verify_on_exit!

  describe "import_movie/1" do
    test "cree le film depuis la charge utile TMDB" do
      expect(TMDBMock, :get_movie, fn 693_134 -> {:ok, movie()} end)

      assert {:ok, work} = Importer.import_movie(693_134)
      assert work.kind == :movie
      assert work.title == "Dune, deuxième partie"
      assert work.imdb_id == "tt15239678"
      assert work.synced_at
    end

    test "remonte l'absence sans creer d'oeuvre" do
      expect(TMDBMock, :get_movie, fn _ -> {:error, :not_found} end)

      assert Importer.import_movie(1) == {:error, :not_found}
    end

    test "met a jour un film deja importe" do
      expect(TMDBMock, :get_movie, 2, fn _ -> {:ok, movie()} end)

      {:ok, first} = Importer.import_movie(693_134)
      {:ok, second} = Importer.import_movie(693_134)

      assert first.id == second.id
    end
  end

  describe "import_season/2" do
    test "cree la saison et tous ses episodes" do
      show = tv_show_fixture()
      expect(TMDBMock, :get_season, fn _, 1 -> {:ok, season()} end)

      assert {:ok, saison} = Importer.import_season(show, 1)
      assert saison.kind == :season
      assert length(Catalog.list_episodes(saison)) == 2
    end

    test "ignore un episode refuse sans perdre la saison" do
      # TMDB publie parfois des episodes sans numero : ils ne doivent pas
      # emporter la saison entiere.
      show = tv_show_fixture()
      bancal = %{"id" => 99, "name" => "Sans numero", "season_number" => 1}

      expect(TMDBMock, :get_season, fn _, 1 ->
        {:ok, season(%{"episodes" => [episode(), bancal]})}
      end)

      assert {:ok, saison} = Importer.import_season(show, 1)
      assert length(Catalog.list_episodes(saison)) == 1
    end

    test "remonte l'erreur TMDB sans rien ecrire" do
      show = tv_show_fixture()
      expect(TMDBMock, :get_season, fn _, _ -> {:error, :rate_limited} end)

      assert Importer.import_season(show, 1) == {:error, :rate_limited}
      assert Catalog.list_seasons(show) == []
    end
  end

  describe "import_all_seasons/1" do
    test "importe autant de saisons que la serie en declare" do
      show = tv_show_fixture(%{season_count: 2})

      # Chaque saison a son propre identifiant TMDB : sans cela l'upsert sur
      # (kind, tmdb_id) ecraserait la premiere par la seconde.
      expect(TMDBMock, :get_season, 2, fn _, number ->
        {:ok,
         season(%{
           "id" => 200_000 + number,
           "season_number" => number,
           "name" => "Saison #{number}",
           "episodes" => [episode(%{"id" => 300_000 + number, "season_number" => number})]
         })}
      end)

      Importer.import_all_seasons(show)

      assert Enum.map(Catalog.list_seasons(show), & &1.season_number) == [1, 2]
    end

    test "ne tente rien sans decompte de saisons" do
      show = tv_show_fixture(%{season_count: nil})

      assert Importer.import_all_seasons(show) == []
    end
  end

  describe "import_results/1" do
    test "importe films et series, ignore les personnes" do
      results = [search_movie(), search_tv(), search_person()]

      assert [a, b] = Importer.import_results(results)
      assert Enum.sort([a.kind, b.kind]) == [:movie, :tv_show]
    end

    test "accepte une liste vide" do
      assert Importer.import_results([]) == []
    end
  end
end
