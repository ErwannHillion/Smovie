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
end
