defmodule Smovie.CatalogFixtures do
  @moduledoc """
  Fixtures du catalogue.

  Les identifiants TMDB sont tires d'un compteur : deux oeuvres creees dans le
  meme test ne doivent pas se telescoper sur l'index unique (kind, tmdb_id).
  """

  alias Smovie.Catalog

  def unique_tmdb_id, do: System.unique_integer([:positive])

  def movie_fixture(attrs \\ %{}) do
    {:ok, movie} =
      attrs
      |> Enum.into(%{
        kind: :movie,
        tmdb_id: unique_tmdb_id(),
        title: "Dune, deuxième partie",
        original_title: "Dune: Part Two",
        overview: "Paul Atréides s'unit aux Fremen.",
        release_date: ~D[2024-02-28],
        runtime: 166,
        poster_path: "/poster.jpg",
        tmdb_popularity: Decimal.new("120.5"),
        tmdb_vote_average: Decimal.new("8.20"),
        tmdb_vote_count: 4200
      })
      |> Catalog.upsert_work()

    movie
  end

  def tv_show_fixture(attrs \\ %{}) do
    {:ok, show} =
      attrs
      |> Enum.into(%{
        kind: :tv_show,
        tmdb_id: unique_tmdb_id(),
        title: "Severance",
        original_title: "Severance",
        release_date: ~D[2022-02-18],
        season_count: 2,
        episode_count: 19,
        tmdb_popularity: Decimal.new("98.1")
      })
      |> Catalog.upsert_work()

    show
  end

  def season_fixture(show, attrs \\ %{}) do
    {:ok, season} =
      attrs
      |> Enum.into(%{
        kind: :season,
        parent_id: show.id,
        tmdb_id: unique_tmdb_id(),
        title: "Saison 1",
        season_number: 1,
        episode_count: 9
      })
      |> Catalog.upsert_work()

    season
  end

  def episode_fixture(season, attrs \\ %{}) do
    {:ok, episode} =
      attrs
      |> Enum.into(%{
        kind: :episode,
        parent_id: season.id,
        tmdb_id: unique_tmdb_id(),
        title: "Bonnes nouvelles de l'enfer",
        season_number: season.season_number,
        episode_number: 1,
        runtime: 48
      })
      |> Catalog.upsert_work()

    episode
  end
end
