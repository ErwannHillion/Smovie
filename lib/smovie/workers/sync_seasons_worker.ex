defmodule Smovie.Workers.SyncSeasonsWorker do
  @moduledoc """
  Importe les saisons et les episodes d'une serie.

  Mis en file a l'ouverture d'une fiche serie dont les saisons manquent : la
  page s'affiche avec ce qu'on a, et les saisons apparaissent au prochain
  chargement. Importer dans le cycle de requete ferait attendre un appel TMDB
  par saison — une serie de dix saisons bloquerait la page dix fois.
  """
  use Oban.Worker, queue: :catalog, max_attempts: 3, unique: [period: 900]

  alias Smovie.Catalog.Sync.Importer
  alias Smovie.Catalog.Work
  alias Smovie.Repo

  @impl true
  def perform(%Oban.Job{args: %{"show_id" => show_id}}) do
    case Repo.get(Work, show_id) do
      %Work{kind: :tv_show} = show -> import_seasons(show)
      _absent -> {:cancel, :show_not_found}
    end
  end

  defp import_seasons(show) do
    case Importer.import_all_seasons(show) do
      [] ->
        {:cancel, :no_seasons_declared}

      results ->
        if Enum.any?(results, &match?({:ok, _}, &1)), do: :ok, else: {:error, :import_failed}
    end
  end

  @doc """
  Met une serie en file d'import de ses saisons.
  """
  def enqueue(%Work{kind: :tv_show, id: show_id}) do
    %{show_id: show_id} |> new() |> Oban.insert()
  end
end
