defmodule Smovie.Catalog.Sync.OMDbMapperTest do
  use ExUnit.Case, async: true

  import Smovie.TMDBPayloads

  alias Smovie.Catalog.Sync.OMDbMapper

  defp by_source(payload) do
    payload |> OMDbMapper.rating_attrs(1) |> Map.new(&{&1.source, &1})
  end

  describe "rating_attrs/2" do
    test "traduit les trois sources avec leur echelle" do
      ratings = by_source(omdb())

      assert Decimal.equal?(ratings[:imdb].score, Decimal.new("8.5"))
      assert ratings[:imdb].scale == 10
      assert Decimal.equal?(ratings[:metacritic].score, Decimal.new("79"))
      assert ratings[:metacritic].scale == 100
      assert Decimal.equal?(ratings[:rotten_tomatoes].score, Decimal.new("92"))
      assert ratings[:rotten_tomatoes].scale == 100
    end

    test "retire les separateurs de milliers du nombre de votes" do
      # "612,483" ferait echouer un Integer.parse direct.
      assert by_source(omdb())[:imdb].votes_count == 612_483
    end

    test "retire le pourcentage de Rotten Tomatoes" do
      assert by_source(omdb())[:rotten_tomatoes].scale == 100
    end

    test "ignore les notes marquees N/A" do
      # OMDb ecrit "N/A" la ou la note manque, et non null.
      ratings = by_source(omdb(%{"imdbRating" => "N/A", "Metascore" => "N/A"}))

      refute Map.has_key?(ratings, :imdb)
      refute Map.has_key?(ratings, :metacritic)
      assert Map.has_key?(ratings, :rotten_tomatoes)
    end

    test "accepte l'absence de Rotten Tomatoes" do
      ratings = by_source(omdb(%{"Ratings" => []}))

      assert Map.has_key?(ratings, :imdb)
      refute Map.has_key?(ratings, :rotten_tomatoes)
    end

    test "ignore un nombre de votes illisible" do
      assert by_source(omdb(%{"imdbVotes" => "N/A"}))[:imdb].votes_count == nil
    end

    test "construit l'URL IMDb" do
      assert by_source(omdb())[:imdb].url == "https://www.imdb.com/title/tt15239678/"
    end

    test "ne rend rien sur une fiche vide" do
      assert OMDbMapper.rating_attrs(%{}, 1) == []
    end
  end
end
