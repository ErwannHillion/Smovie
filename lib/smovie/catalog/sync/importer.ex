defmodule Smovie.Catalog.Sync.Importer do
  @moduledoc """
  Importe des oeuvres depuis TMDB.

  Le catalogue n'est pas aspire : TMDB depasse le million d'oeuvres, et la
  quasi-totalite n'interessera jamais personne ici. Trois voies d'alimentation
  seulement :

  1. **a la demande** — une oeuvre absente est importee au premier clic sur sa
     fiche ;
  2. **planifiee** — les sorties et les tendances, chaque nuit ;
  3. **rafraichissement** — une oeuvre consultee dont la synchro a vieilli est
     remise en file.

  Les saisons et les episodes ne sont importes qu'au premier affichage de la
  serie : un appel par saison ramene tous ses episodes d'un coup.
  """

  require Logger

  alias Smovie.Catalog
  alias Smovie.Catalog.Sync.Mapper
  alias Smovie.Catalog.Work
  alias Smovie.External.TMDB
  alias Smovie.Repo

  @doc """
  Importe un film par son identifiant TMDB.
  """
  def import_movie(tmdb_id) do
    case TMDB.get_movie(tmdb_id) do
      {:ok, payload} -> payload |> Mapper.movie_attrs() |> import_with_relations(payload)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Importe une serie par son identifiant TMDB, sans ses saisons.
  """
  def import_tv_show(tmdb_id) do
    case TMDB.get_tv_show(tmdb_id) do
      {:ok, payload} -> payload |> Mapper.tv_show_attrs() |> import_with_relations(payload)
      {:error, reason} -> {:error, reason}
    end
  end

  # Genres et casting ne viennent que des charges utiles de detail : un
  # resultat de recherche n'a que des identifiants de genre et aucun casting.
  defp import_with_relations(attrs, payload) do
    case Catalog.upsert_work(attrs) do
      {:ok, work} ->
        payload
        |> Mapper.genre_attrs()
        |> Catalog.upsert_genres()
        |> then(&Catalog.put_work_genres(work, &1))

        payload |> Mapper.credit_attrs() |> then(&Catalog.put_work_credits(work, &1))

        {:ok, work}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Importe une oeuvre par sa nature et son identifiant TMDB.
  """
  def import_work(:movie, tmdb_id), do: import_movie(tmdb_id)
  def import_work(:tv_show, tmdb_id), do: import_tv_show(tmdb_id)

  @doc """
  Importe une saison et tous ses episodes.

  La saison et ses episodes entrent dans une seule transaction : une saison
  sans ses episodes afficherait une progression fausse, et l'utilisateur
  n'aurait aucun moyen de comprendre pourquoi.
  """
  def import_season(%Work{kind: :tv_show} = show, season_number) do
    case TMDB.get_season(show.tmdb_id, season_number) do
      {:ok, payload} -> insert_season(show, payload)
      {:error, reason} -> {:error, reason}
    end
  end

  defp insert_season(show, payload) do
    Repo.transaction(fn ->
      case payload |> Mapper.season_attrs(show.id) |> Catalog.upsert_work() do
        {:ok, season} ->
          insert_episodes(payload, season)
          season

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  defp insert_episodes(payload, season) do
    payload
    |> Mapper.episodes_of(season.id)
    |> Enum.each(fn attrs ->
      case Catalog.upsert_work(attrs) do
        {:ok, _episode} ->
          :ok

        {:error, changeset} ->
          # Un episode refuse ne doit pas faire echouer la saison entiere :
          # TMDB publie parfois des episodes sans numero.
          Logger.warning("Episode TMDB ignore : #{inspect(changeset.errors)}")
          :ok
      end
    end)
  end

  @doc """
  Importe toutes les saisons d'une serie.
  """
  def import_all_seasons(%Work{kind: :tv_show, season_count: count} = show)
      when is_integer(count) and count > 0 do
    # La saison 0 regroupe les episodes speciaux : on l'ignore, elle fausserait
    # la numerotation affichee.
    Enum.map(1..count, &import_season(show, &1))
  end

  def import_all_seasons(%Work{kind: :tv_show}), do: []

  @doc """
  Importe une liste de resultats TMDB, en ignorant ce qui n'est ni film ni serie.
  """
  def import_results(results) when is_list(results) do
    results
    |> Enum.map(&Mapper.search_result_attrs/1)
    |> Enum.filter(&match?({:ok, _attrs}, &1))
    |> Enum.map(fn {:ok, attrs} -> Catalog.upsert_work(attrs) end)
    |> Enum.filter(&match?({:ok, _work}, &1))
    |> Enum.map(fn {:ok, work} -> work end)
  end
end
