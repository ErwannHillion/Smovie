defmodule Smovie.External.TMDB do
  @moduledoc """
  Facade du client TMDB.

  L'implementation est choisie par la configuration : le client `Req` en
  developpement et en production, une doublure `Mox` en test. Aucun test ne
  doit sortir sur le reseau — TMDB plafonne le debit, et une suite qui depend
  du reseau echoue pour des raisons qui n'ont rien a voir avec le code.
  """

  alias Smovie.Config

  @doc """
  Recherche films, series et personnes en une requete.
  """
  @callback search_multi(query :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}

  @doc """
  Detail d'un film, credits et identifiants externes compris.
  """
  @callback get_movie(tmdb_id :: integer()) :: {:ok, map()} | {:error, term()}

  @doc """
  Detail d'une serie.
  """
  @callback get_tv_show(tmdb_id :: integer()) :: {:ok, map()} | {:error, term()}

  @doc """
  Detail d'une saison, avec la liste de ses episodes.
  """
  @callback get_season(tmdb_id :: integer(), season_number :: integer()) ::
              {:ok, map()} | {:error, term()}

  @doc """
  Tendances TMDB de la journee ou de la semaine.
  """
  @callback trending(:movie | :tv, :day | :week) :: {:ok, map()} | {:error, term()}

  @doc """
  Films a l'affiche, pour la region configuree.
  """
  @callback now_playing(opts :: keyword()) :: {:ok, map()} | {:error, term()}

  @doc """
  Series en cours de diffusion.
  """
  @callback on_the_air(opts :: keyword()) :: {:ok, map()} | {:error, term()}

  @doc """
  Liste des genres, par type d'oeuvre.
  """
  @callback genres(:movie | :tv) :: {:ok, map()} | {:error, term()}

  def search_multi(query, opts \\ []), do: impl().search_multi(query, opts)
  def get_movie(tmdb_id), do: impl().get_movie(tmdb_id)
  def get_tv_show(tmdb_id), do: impl().get_tv_show(tmdb_id)
  def get_season(tmdb_id, season_number), do: impl().get_season(tmdb_id, season_number)
  def trending(type, window \\ :week), do: impl().trending(type, window)
  def now_playing(opts \\ []), do: impl().now_playing(opts)
  def on_the_air(opts \\ []), do: impl().on_the_air(opts)
  def genres(type), do: impl().genres(type)

  defp impl, do: Config.tmdb_impl()
end
