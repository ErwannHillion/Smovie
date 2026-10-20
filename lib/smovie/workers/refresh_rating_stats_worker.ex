defmodule Smovie.Workers.RefreshRatingStatsWorker do
  @moduledoc """
  Rafraichit la moyenne de la plateforme, qui sert d'a priori bayesien.

  Toutes les heures : la moyenne globale ne bouge que tres lentement, et la
  recalculer a chaque note serait un scan complet de la table des notes.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Smovie.Library

  @impl true
  def perform(%Oban.Job{}) do
    {:ok, _average} = Library.refresh_global_average()
    :ok
  end
end
