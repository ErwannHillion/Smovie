defmodule Smovie.Workers.SyncWorkWorker do
  @moduledoc """
  Rafraichit une oeuvre depuis TMDB.

  Mis en file a la consultation d'une fiche dont la synchro a vieilli : la
  page s'affiche immediatement avec ce qu'on a, et se complete au prochain
  chargement. Faire l'appel dans le cycle de requete rendrait la fiche
  tributaire de la latence de TMDB.
  """
  use Oban.Worker, queue: :catalog, max_attempts: 3, unique: [period: 300]

  alias Smovie.Catalog.Sync.Importer

  @impl true
  def perform(%Oban.Job{args: %{"kind" => kind, "tmdb_id" => tmdb_id}}) do
    case Importer.import_work(String.to_existing_atom(kind), tmdb_id) do
      {:ok, _work} -> :ok
      # Une oeuvre retiree de TMDB ne reviendra pas : inutile de reessayer.
      {:error, :not_found} -> {:cancel, :not_found}
      {:error, :missing_api_key} -> {:cancel, :missing_api_key}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Met une oeuvre en file de rafraichissement.
  """
  def enqueue(kind, tmdb_id) do
    %{kind: Atom.to_string(kind), tmdb_id: tmdb_id}
    |> new()
    |> Oban.insert()
  end
end
