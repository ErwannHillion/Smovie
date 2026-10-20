defmodule Smovie.Catalog.CreditsTest do
  use Smovie.DataCase, async: true

  import Mox
  import Smovie.CatalogFixtures
  import Smovie.TMDBPayloads

  alias Smovie.Catalog
  alias Smovie.Catalog.Sync.Importer
  alias Smovie.Catalog.Sync.Mapper
  alias Smovie.External.TMDBMock

  setup :verify_on_exit!

  describe "Mapper.genre_attrs/1" do
    test "extrait les genres nommes d'un detail" do
      assert Mapper.genre_attrs(movie()) == [
               %{tmdb_id: 878, name: "Science-Fiction"},
               %{tmdb_id: 12, name: "Aventure"}
             ]
    end

    test "ignore les entrees incompletes" do
      payload = %{
        "genres" => [%{"id" => 1}, %{"name" => "Sans id"}, %{"id" => 2, "name" => "Ok"}]
      }

      assert Mapper.genre_attrs(payload) == [%{tmdb_id: 2, name: "Ok"}]
    end

    test "accepte un detail sans genres" do
      assert Mapper.genre_attrs(%{}) == []
    end
  end

  describe "Mapper.credit_attrs/1" do
    test "retient le casting dans l'ordre du generique" do
      credits = Mapper.credit_attrs(movie())
      cast = Enum.filter(credits, &(&1.kind == :cast))

      assert Enum.map(cast, & &1.person.name) == ["Timothée Chalamet", "Zendaya"]
      assert Enum.map(cast, & &1.character) == ["Paul Atreides", "Chani"]
      assert Enum.map(cast, & &1.display_order) == [0, 1]
    end

    test "filtre l'equipe technique sur les postes qui interessent" do
      # Le generique complet compte deux cents lignes : un assistant machiniste
      # n'a rien a faire sur une fiche.
      crew = movie() |> Mapper.credit_attrs() |> Enum.filter(&(&1.kind == :crew))

      assert Enum.map(crew, & &1.job) == ["Director", "Screenplay"]
      refute "Assistant Grip" in Enum.map(crew, & &1.job)
    end

    test "tronque le casting a vingt" do
      cast = for n <- 1..40, do: %{"id" => n, "name" => "A#{n}", "order" => n}
      payload = %{"credits" => %{"cast" => cast, "crew" => []}}

      assert length(Mapper.credit_attrs(payload)) == 20
    end

    test "ecarte une entree sans identifiant" do
      payload = %{"credits" => %{"cast" => [%{"name" => "Anonyme"}], "crew" => []}}

      assert Mapper.credit_attrs(payload) == []
    end

    test "accepte un detail sans credits" do
      assert Mapper.credit_attrs(%{}) == []
    end
  end

  describe "genres en base" do
    test "upsert_genres/1 ne cree pas de doublon" do
      attrs = [%{tmdb_id: 878, name: "Science-Fiction"}]

      [first] = Catalog.upsert_genres(attrs)
      [second] = Catalog.upsert_genres(attrs)

      assert first.id == second.id
      assert first.slug == "science-fiction"
    end

    test "put_work_genres/2 remplace les genres precedents" do
      # Un genre retire chez TMDB doit disparaitre ici, sinon la fiche
      # accumule des etiquettes que plus personne ne corrige.
      movie = movie_fixture()
      sf = Catalog.upsert_genres([%{tmdb_id: 878, name: "Science-Fiction"}])
      comedie = Catalog.upsert_genres([%{tmdb_id: 35, name: "Comédie"}])

      Catalog.put_work_genres(movie, sf)
      assert Enum.map(Catalog.list_work_genres(movie), & &1.name) == ["Science-Fiction"]

      Catalog.put_work_genres(movie, comedie)
      assert Enum.map(Catalog.list_work_genres(movie), & &1.name) == ["Comédie"]
    end

    test "supprimer une oeuvre detache ses genres" do
      movie = movie_fixture()
      genres = Catalog.upsert_genres([%{tmdb_id: 878, name: "Science-Fiction"}])
      Catalog.put_work_genres(movie, genres)

      Smovie.Repo.delete!(movie)

      assert Smovie.Repo.aggregate(Smovie.Catalog.WorkGenre, :count) == 0
      assert Smovie.Repo.aggregate(Smovie.Catalog.Genre, :count) == 1
    end
  end

  describe "casting en base" do
    setup do
      %{movie: movie_fixture()}
    end

    test "put_work_credits/2 cree les personnes et leurs participations", %{movie: movie} do
      {:ok, count} = Catalog.put_work_credits(movie, Mapper.credit_attrs(movie()))

      assert count == 4
      assert Enum.map(Catalog.list_directors(movie), & &1.name) == ["Denis Villeneuve"]
      assert length(Catalog.list_cast(movie)) == 2
    end

    test "une personne jouant sur deux oeuvres n'est creee qu'une fois", %{movie: movie} do
      autre = movie_fixture(%{title: "Un autre film"})
      credits = Mapper.credit_attrs(movie())

      Catalog.put_work_credits(movie, credits)
      Catalog.put_work_credits(autre, credits)

      assert Smovie.Repo.aggregate(Smovie.Catalog.Person, :count) == 4
    end

    test "une personne peut tenir deux postes sur la meme oeuvre", %{movie: movie} do
      # Realisatrice et scenariste : deux lignes, une seule personne.
      payload = %{
        "credits" => %{
          "cast" => [],
          "crew" => [
            %{
              "id" => 7,
              "name" => "Greta Gerwig",
              "job" => "Director",
              "department" => "Directing"
            },
            %{
              "id" => 7,
              "name" => "Greta Gerwig",
              "job" => "Screenplay",
              "department" => "Writing"
            }
          ]
        }
      }

      {:ok, count} = Catalog.put_work_credits(movie, Mapper.credit_attrs(payload))

      assert count == 2
      assert Smovie.Repo.aggregate(Smovie.Catalog.Person, :count) == 1
    end

    test "remplace les participations precedentes", %{movie: movie} do
      Catalog.put_work_credits(movie, Mapper.credit_attrs(movie()))
      Catalog.put_work_credits(movie, [])

      assert Catalog.list_cast(movie) == []
      assert Catalog.list_directors(movie) == []
    end

    test "le slug d'une personne inclut son identifiant TMDB", %{movie: movie} do
      # Deux homonymes existent : un suffixe numerique arbitraire serait moins
      # stable qu'un identifiant qui ne change jamais.
      Catalog.put_work_credits(movie, Mapper.credit_attrs(movie()))

      assert [%{slug: "denis-villeneuve-137427"}] = Catalog.list_directors(movie)
    end
  end

  describe "import complet" do
    test "un film importe arrive avec ses genres et son casting" do
      expect(TMDBMock, :get_movie, fn _ -> {:ok, movie()} end)

      {:ok, work} = Importer.import_movie(693_134)

      assert Enum.map(Catalog.list_work_genres(work), & &1.name) == [
               "Aventure",
               "Science-Fiction"
             ]

      assert Enum.map(Catalog.list_directors(work), & &1.name) == ["Denis Villeneuve"]
      assert length(Catalog.list_cast(work)) == 2
    end
  end
end
