defmodule Smovie.Workers.SyncTrendingCatalogWorker do
  @moduledoc """
  Alimente le catalogue chaque nuit.

  Sorties en salle de la region, series en cours de diffusion, et tendances de
  la semaine : de l'ordre de 150 oeuvres par execution, soit ce qu'il faut
  pour qu'un nouvel arrivant trouve une page d'accueil remplie sans que
  personne n'ait rien cherche.
  """
  use Oban.Worker, queue: :catalog, max_attempts: 3

  require Logger

  alias Smovie.Catalog.Sync.Importer
  alias Smovie.External.TMDB

  @sources [:now_playing, :on_the_air, :trending_movies, :trending_tv]

  @impl true
  def perform(%Oban.Job{}) do
    total = @sources |> Enum.map(&import_source/1) |> Enum.sum()

    if total == 0 do
      # Zero oeuvre sur quatre sources, c'est une panne et non un creux :
      # mieux vaut que le job echoue et soit reessaye.
      {:error, :no_work_imported}
    else
      Logger.info("Catalogue : #{total} oeuvres synchronisees")
      :ok
    end
  end

  defp import_source(name) do
    case fetch(name) do
      {:ok, %{"results" => results}} ->
        results |> Importer.import_results() |> length()

      {:ok, _unexpected} ->
        0

      {:error, reason} ->
        # Une source en panne ne doit pas emporter les trois autres.
        Logger.warning("Synchro #{name} echouee : #{inspect(reason)}")
        0
    end
  end

  defp fetch(:now_playing), do: TMDB.now_playing()
  defp fetch(:on_the_air), do: TMDB.on_the_air()
  defp fetch(:trending_movies), do: TMDB.trending(:movie, :week)
  defp fetch(:trending_tv), do: TMDB.trending(:tv, :week)
end
