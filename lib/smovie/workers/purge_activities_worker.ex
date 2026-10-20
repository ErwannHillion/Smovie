defmodule Smovie.Workers.PurgeActivitiesWorker do
  @moduledoc """
  Purge les activites anciennes.

  Un fil ne se consulte pas au-dela de quelques semaines : conserver
  indefiniment ferait grossir la table sans que personne n'y gagne.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  alias Smovie.Social

  @impl true
  def perform(%Oban.Job{}) do
    {:ok, count} = Social.purge_activities()
    Logger.info("Fil d'activite : #{count} entrees purgees")
    :ok
  end
end
