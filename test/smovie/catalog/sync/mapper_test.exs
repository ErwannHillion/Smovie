defmodule Smovie.Catalog.Sync.MapperTest do
  use ExUnit.Case, async: true

  import Smovie.TMDBPayloads

  alias Smovie.Catalog.Sync.Mapper

  describe "movie_attrs/1" do
    test "traduit les champs attendus" do
      attrs = Mapper.movie_attrs(movie())

      assert attrs.kind == :movie
      assert attrs.tmdb_id == 693_134
      assert attrs.title == "Dune, deuxième partie"
      assert attrs.original_title == "Dune: Part Two"
      assert attrs.release_date == ~D[2024-02-27]
      assert attrs.runtime == 167
      assert attrs.imdb_id == "tt15239678"
      assert Decimal.equal?(attrs.tmdb_vote_average, Decimal.from_float(8.157))
    end

    test "traite la chaine vide des dates absentes" do
      # TMDB renvoie "" et non null : Date.from_iso8601("") echouerait.
      assert Mapper.movie_attrs(movie(%{"release_date" => ""})).release_date == nil
    end

    test "traite une date mal formee sans lever" do
      assert Mapper.movie_attrs(movie(%{"release_date" => "2024-02"})).release_date == nil
    end

    test "ramene une duree de zero a nil" do
      # TMDB renvoie 0 pour une duree inconnue : 0 minute serait faux.
      assert Mapper.movie_attrs(movie(%{"runtime" => 0})).runtime == nil
      assert Mapper.movie_attrs(movie(%{"runtime" => nil})).runtime == nil
    end

    test "vide les chaines blanches" do
      attrs = Mapper.movie_attrs(movie(%{"overview" => "   ", "tagline" => ""}))

      assert attrs.overview == nil
      assert attrs.tagline == nil
    end

    test "retombe sur le titre original quand le titre manque" do
      attrs = Mapper.movie_attrs(movie(%{"title" => ""}))

      assert attrs.title == "Dune: Part Two"
    end

    test "retombe sur un libelle quand aucun titre n'existe" do
      # Un titre absent produirait un changeset invalide et perdrait l'oeuvre.
      attrs = Mapper.movie_attrs(%{"id" => 1})

      assert attrs.title == "Sans titre"
    end

    test "lit imdb_id a la racine comme dans external_ids" do
      assert Mapper.movie_attrs(%{"id" => 1, "imdb_id" => "tt42"}).imdb_id == "tt42"

      assert Mapper.movie_attrs(%{"id" => 1, "external_ids" => %{"imdb_id" => "tt43"}}).imdb_id ==
               "tt43"

      assert Mapper.movie_attrs(%{"id" => 1}).imdb_id == nil
    end

    test "ne marque adulte que sur un booleen vrai" do
      assert Mapper.movie_attrs(movie(%{"adult" => true})).adult == true
      assert Mapper.movie_attrs(movie(%{"adult" => "true"})).adult == false
      assert Mapper.movie_attrs(movie(%{})).adult == false
    end
  end

  describe "tv_show_attrs/1" do
    test "traduit les champs propres aux series" do
      attrs = Mapper.tv_show_attrs(tv_show())

      assert attrs.kind == :tv_show
      assert attrs.title == "Severance"
      assert attrs.release_date == ~D[2022-02-18]
      assert attrs.season_count == 2
      assert attrs.episode_count == 19
    end

    test "retient la duree d'episode la plus courte" do
      # TMDB liste plusieurs formats pour une meme serie ; le plus court est
      # le format usuel, les autres sont des episodes speciaux.
      assert Mapper.tv_show_attrs(tv_show(%{"episode_run_time" => [55, 48, 90]})).runtime == 48
    end

    test "gere une liste de durees vide" do
      assert Mapper.tv_show_attrs(tv_show(%{"episode_run_time" => []})).runtime == nil
    end
  end

  describe "season_attrs/2 et episode_attrs/2" do
    test "rattachent l'oeuvre a son parent" do
      assert Mapper.season_attrs(season(), 7).parent_id == 7
      assert Mapper.episode_attrs(episode(), 9).parent_id == 9
    end

    test "comptent les episodes d'une saison" do
      assert Mapper.season_attrs(season(), 7).episode_count == 2
    end

    test "episodes_of/2 traduit toute la liste" do
      episodes = Mapper.episodes_of(season(), 7)

      assert length(episodes) == 2
      assert Enum.map(episodes, & &1.episode_number) == [1, 2]
      assert Enum.all?(episodes, &(&1.parent_id == 7))
    end

    test "episodes_of/2 accepte une saison sans episodes" do
      assert Mapper.episodes_of(%{"season_number" => 1}, 7) == []
    end
  end

  describe "kind_of/1" do
    test "distingue les natures d'un resultat de recherche" do
      # TMDB melange films, series et personnes dans la meme liste.
      assert Mapper.kind_of(search_movie()) == {:ok, :movie}
      assert Mapper.kind_of(search_tv()) == {:ok, :tv_show}
      assert Mapper.kind_of(search_person()) == {:ok, :person}
      assert Mapper.kind_of(%{}) == :error
    end

    test "search_result_attrs/1 ecarte les personnes" do
      assert {:ok, %{kind: :movie}} = Mapper.search_result_attrs(search_movie())
      assert {:ok, %{kind: :tv_show}} = Mapper.search_result_attrs(search_tv())
      assert Mapper.search_result_attrs(search_person()) == :error
    end
  end
end
