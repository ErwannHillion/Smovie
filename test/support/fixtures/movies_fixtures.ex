defmodule Smovie.MoviesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Smovie.Movies` context.
  """

  @doc """
  Generate a watched_list.
  """
  def watched_list_fixture(attrs \\ %{}) do
    {:ok, watched_list} =
      attrs
      |> Enum.into(%{
        udescription: "some udescription",
        urating: 120.5,
        uwatcheddate: ~D[2025-02-23]
      })
      |> Smovie.Movies.create_watched_list()

    watched_list
  end

  @doc """
  Generate a watch_later.
  """
  def watch_later_fixture(attrs \\ %{}) do
    {:ok, watch_later} =
      attrs
      |> Enum.into(%{
        id_movie: 42,
        movie_description: "some movie_description",
        movie_title: "some movie_title"
      })
      |> Smovie.Movies.create_watch_later()

    watch_later
  end
end
