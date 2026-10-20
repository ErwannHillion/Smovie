defmodule Smovie.Workers.FetchExternalRatingsWorker do
  @moduledoc """
  Recupere les notes presse d'une oeuvre chez OMDb.

  La file `external_ratings` est a concurrence 2 : elle sert de limiteur de
  debit. Le palier gratuit d'OMDb plafonne a mille requetes par jour, ce qui
  fait du cache et de l'etalement une condition de fonctionnement et non une
  optimisation.

  Un compteur journalier, expirant a minuit, repousse les jobs au lendemain
  plutot que de les faire echouer une fois le quota atteint.
  """
  use Oban.Worker, queue: :external_ratings, max_attempts: 3, unique: [period: 3600]

  require Logger

  alias Smovie.Catalog
  alias Smovie.Catalog.Sync.OMDbMapper
  alias Smovie.Catalog.Work
  alias Smovie.Config
  alias Smovie.External.OMDb
  alias Smovie.Repo

  @cache :smovie_http_cache
  @counter_key {:omdb, :daily_count}

  @impl true
  def perform(%Oban.Job{args: %{"work_id" => work_id}}) do
    with {:ok, work} <- fetch_work(work_id),
         :ok <- check_quota() do
      fetch_ratings(work)
    end
  end

  defp fetch_work(work_id) do
    case Repo.get(Work, work_id) do
      # Une oeuvre supprimee entre la mise en file et l'execution n'est pas une
      # erreur : le job n'a simplement plus d'objet.
      nil -> {:cancel, :work_deleted}
      %Work{imdb_id: nil} -> {:cancel, :no_imdb_id}
      work -> {:ok, work}
    end
  end

  defp fetch_ratings(work) do
    case OMDb.get_by_imdb_id(work.imdb_id) do
      {:ok, payload} ->
        increment_counter()
        Catalog.put_external_ratings(work, OMDbMapper.rating_attrs(payload, work.id))
        :ok

      {:error, :quota_exceeded} ->
        {:snooze, seconds_until_midnight()}

      {:error, reason} when reason in [:disabled, :missing_api_key, :not_found, :unauthorized] ->
        {:cancel, reason}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Met une oeuvre en file de recuperation des notes presse.
  """
  def enqueue(%Work{imdb_id: nil}), do: {:ok, :no_imdb_id}

  def enqueue(%Work{id: work_id}) do
    %{work_id: work_id} |> new() |> Oban.insert()
  end

  # Le compteur expire a minuit : le quota d'OMDb est journalier, pas glissant.
  defp check_quota do
    case Cachex.get(@cache, @counter_key) do
      {:ok, count} when is_integer(count) and count >= 0 ->
        if count < Config.omdb_daily_quota(), do: :ok, else: {:snooze, seconds_until_midnight()}

      _absent ->
        :ok
    end
  end

  defp increment_counter do
    Cachex.incr(@cache, @counter_key, 1, default: 0)
    Cachex.expire(@cache, @counter_key, :timer.seconds(seconds_until_midnight()))
  end

  defp seconds_until_midnight do
    now = DateTime.utc_now()
    midnight = DateTime.new!(Date.add(DateTime.to_date(now), 1), ~T[00:00:00], "Etc/UTC")

    DateTime.diff(midnight, now)
  end
end
