defmodule Smovie.Workers.RefreshTrendingWorker do
  @moduledoc """
  Rafraichit la vue des tendances.

  Toutes les quinze minutes : assez souvent pour qu'une poussee se voie dans
  la journee, assez rare pour qu'un REFRESH CONCURRENTLY sur toute la table ne
  pese pas.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Smovie.Trending

  @impl true
  def perform(%Oban.Job{}) do
    Trending.refresh()
  end
end
