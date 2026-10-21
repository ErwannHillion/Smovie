defmodule Smovie.Catalog.Bootstrap do
  @moduledoc """
  Amorce le catalogue au demarrage s'il est vide.

  Sans cela, une installation neuve reste sur une page d'accueil vide jusqu'a
  la prochaine synchronisation planifiee — jusqu'a six heures pendant
  lesquelles l'application a l'air cassee alors qu'elle attend simplement son
  tour. Personne ne devrait avoir a lancer un job a la main pour que le
  produit demarre.

  La tache est idempotente : elle ne fait rien si le catalogue contient deja
  de quoi remplir une page d'accueil. Un redemarrage ne declenche donc pas
  d'appel inutile.

  Elle ne bloque pas le demarrage : une panne TMDB ou une base pas encore
  migree doit laisser l'application monter, quitte a ce que l'accueil reste
  vide le temps d'un cycle.
  """
  use Task, restart: :temporary

  require Logger

  import Ecto.Query, warn: false

  alias Smovie.Catalog.Work
  alias Smovie.Config
  alias Smovie.Repo
  alias Smovie.Workers.SyncTrendingCatalogWorker

  def start_link(_opts), do: Task.start_link(__MODULE__, :run, [])

  @doc """
  Met le catalogue en file si l'amorcage est actif et le catalogue trop maigre.
  """
  def run do
    if Config.bootstrap_catalog?() do
      maybe_enqueue()
    else
      :ok
    end
  rescue
    # Base absente, pas encore migree, ou TMDB injoignable : l'application
    # doit monter quand meme.
    error ->
      Logger.warning("Amorcage du catalogue ignore : #{Exception.message(error)}")
      :ok
  end

  defp maybe_enqueue do
    count = Repo.aggregate(from(w in Work, where: w.kind in [:movie, :tv_show]), :count)

    if count < Config.bootstrap_threshold() do
      Logger.info("Catalogue a #{count} oeuvres : synchronisation initiale mise en file")

      %{} |> SyncTrendingCatalogWorker.new() |> Oban.insert()
    end

    :ok
  end
end
