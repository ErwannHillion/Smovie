defmodule Smovie.TMDBPayloads do
  @moduledoc """
  Charges utiles TMDB figees, reduites aux champs que l'application lit.

  Elles reproduisent les particularites du format reel : chaines vides pour
  les dates absentes, zeros pour les durees inconnues, `external_ids`
  imbriques.
  """

  def movie(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => 693_134,
        "title" => "Dune, deuxième partie",
        "original_title" => "Dune: Part Two",
        "overview" => "Paul Atréides s'unit à Chani et aux Fremen.",
        "tagline" => "Longue vie aux combattants",
        "release_date" => "2024-02-27",
        "runtime" => 167,
        "poster_path" => "/dune2.jpg",
        "backdrop_path" => "/dune2-backdrop.jpg",
        "original_language" => "en",
        "status" => "Released",
        "adult" => false,
        "popularity" => 182.456,
        "vote_average" => 8.157,
        "vote_count" => 4821,
        "external_ids" => %{"imdb_id" => "tt15239678"},
        "genres" => [
          %{"id" => 878, "name" => "Science-Fiction"},
          %{"id" => 12, "name" => "Aventure"}
        ],
        "credits" => %{
          "cast" => [
            %{
              "id" => 1_190_668,
              "name" => "Timothée Chalamet",
              "character" => "Paul Atreides",
              "order" => 0,
              "profile_path" => "/tc.jpg"
            },
            %{"id" => 505_710, "name" => "Zendaya", "character" => "Chani", "order" => 1}
          ],
          "crew" => [
            %{
              "id" => 137_427,
              "name" => "Denis Villeneuve",
              "job" => "Director",
              "department" => "Directing"
            },
            %{
              "id" => 9_545,
              "name" => "Jon Spaihts",
              "job" => "Screenplay",
              "department" => "Writing"
            },
            %{"id" => 1, "name" => "Quelqu un", "job" => "Assistant Grip", "department" => "Crew"}
          ]
        }
      },
      overrides
    )
  end

  def tv_show(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => 95_396,
        "name" => "Severance",
        "original_name" => "Severance",
        "overview" => "Chez Lumon Industries, un procédé sépare les souvenirs.",
        "first_air_date" => "2022-02-18",
        "episode_run_time" => [48, 55],
        "number_of_seasons" => 2,
        "number_of_episodes" => 19,
        "poster_path" => "/severance.jpg",
        "original_language" => "en",
        "status" => "Returning Series",
        "popularity" => 98.1,
        "vote_average" => 8.4,
        "vote_count" => 2104,
        "external_ids" => %{"imdb_id" => "tt11280740"}
      },
      overrides
    )
  end

  def season(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => 118_677,
        "name" => "Saison 1",
        "season_number" => 1,
        "air_date" => "2022-02-18",
        "overview" => "",
        "poster_path" => "/s1.jpg",
        "episodes" => [
          episode(),
          episode(%{"id" => 2, "episode_number" => 2, "name" => "Moitié mortelle"})
        ]
      },
      overrides
    )
  end

  def episode(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => 1,
        "name" => "Bonnes nouvelles de l'enfer",
        "season_number" => 1,
        "episode_number" => 1,
        "air_date" => "2022-02-18",
        "overview" => "Mark dirige une équipe de quatre personnes.",
        "runtime" => 48,
        "vote_average" => 7.9,
        "vote_count" => 120
      },
      overrides
    )
  end

  def search_multi(results) do
    %{"page" => 1, "total_pages" => 1, "total_results" => length(results), "results" => results}
  end

  def search_movie(overrides \\ %{}),
    do: movie(Map.merge(%{"media_type" => "movie"}, overrides))

  def search_tv(overrides \\ %{}),
    do: tv_show(Map.merge(%{"media_type" => "tv"}, overrides))

  def search_person(overrides \\ %{}) do
    Map.merge(
      %{"id" => 1_190_668, "name" => "Timothée Chalamet", "media_type" => "person"},
      overrides
    )
  end

  @doc "Fiche OMDb, avec ses formats de chaines caracteristiques."
  def omdb(overrides \\ %{}) do
    Map.merge(
      %{
        "Response" => "True",
        "Title" => "Dune: Part Two",
        "imdbID" => "tt15239678",
        "imdbRating" => "8.5",
        "imdbVotes" => "612,483",
        "Metascore" => "79",
        "Ratings" => [
          %{"Source" => "Internet Movie Database", "Value" => "8.5/10"},
          %{"Source" => "Rotten Tomatoes", "Value" => "92%"},
          %{"Source" => "Metacritic", "Value" => "79/100"}
        ]
      },
      overrides
    )
  end
end
