defmodule Smovie.Catalog do
  @moduledoc """
  Le catalogue : films, series, saisons, episodes.

  Donnees de reference, partagees par tous les membres. Rien ici ne depend de
  qui regarde — ce qui distingue ce contexte de `Smovie.Library`, qui porte ce
  qu'un membre fait des oeuvres et n'est lisible que sous autorisation.
  """

  import Ecto.Query, warn: false

  alias Smovie.Catalog.Slug
  alias Smovie.Catalog.Work
  alias Smovie.Config
  alias Smovie.Repo

  ## Lecture

  @doc """
  Recupere une oeuvre par son slug, ou `nil`.
  """
  def get_work_by_slug(slug) when is_binary(slug), do: Repo.get_by(Work, slug: slug)

  @doc """
  Recupere un film par son slug. Un slug de serie ne doit pas ouvrir `/film/`.
  """
  def get_movie_by_slug(slug) when is_binary(slug),
    do: Repo.get_by(Work, slug: slug, kind: :movie)

  @doc """
  Recupere une serie par son slug.
  """
  def get_tv_show_by_slug(slug) when is_binary(slug),
    do: Repo.get_by(Work, slug: slug, kind: :tv_show)

  @doc """
  Recupere une oeuvre par sa nature et son identifiant TMDB.
  """
  def get_work_by_tmdb_id(kind, tmdb_id), do: Repo.get_by(Work, kind: kind, tmdb_id: tmdb_id)

  @doc """
  Saisons d'une serie, dans l'ordre.
  """
  def list_seasons(%Work{kind: :tv_show, id: id}) do
    Repo.all(
      from w in Work, where: w.parent_id == ^id and w.kind == :season, order_by: w.season_number
    )
  end

  @doc """
  Episodes d'une saison, dans l'ordre.
  """
  def list_episodes(%Work{kind: :season, id: id}) do
    Repo.all(
      from w in Work, where: w.parent_id == ^id and w.kind == :episode, order_by: w.episode_number
    )
  end

  @doc """
  Une saison d'une serie, par son numero.
  """
  def get_season(%Work{kind: :tv_show, id: id}, number) do
    Repo.get_by(Work, parent_id: id, kind: :season, season_number: number)
  end

  @doc """
  Sorties recentes, classees par popularite TMDB.

  Par popularite et non par activite Smovie : une nouveaute n'a pas encore
  d'audience interne, la trier par notes reviendrait a la cacher.
  """
  def list_recent_releases(kind \\ :movie, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    window = Keyword.get(opts, :days, 60)
    today = Date.utc_today()

    Repo.all(
      from w in Work,
        where: w.kind == ^kind,
        where: w.release_date >= ^Date.add(today, -window),
        # La borne haute laisse apparaitre les sorties imminentes.
        where: w.release_date <= ^Date.add(today, 7),
        order_by: [desc_nulls_last: w.tmdb_popularity],
        limit: ^limit
    )
  end

  @doc """
  Recherche plein texte sur le catalogue local.

  Repli trigram sur le titre quand le plein texte ne rend rien : une faute de
  frappe ne doit pas produire une page vide alors que l'oeuvre est en base.
  """
  def search(term, opts \\ [])

  def search(term, _opts) when not is_binary(term), do: []

  def search(term, opts) do
    term = String.trim(term)

    if String.length(term) < 3 do
      []
    else
      do_search(term, opts)
    end
  end

  defp do_search(term, opts) do
    limit = Keyword.get(opts, :limit, 20)
    kinds = Keyword.get(opts, :kinds, [:movie, :tv_show])

    case full_text_search(term, kinds, limit) do
      [] -> trigram_search(term, kinds, limit)
      results -> results
    end
  end

  defp full_text_search(term, kinds, limit) do
    Repo.all(
      from w in Work,
        where: w.kind in ^kinds,
        where: fragment("search_vector @@ websearch_to_tsquery('french', ?)", ^term),
        order_by: [
          desc: fragment("ts_rank(search_vector, websearch_to_tsquery('french', ?))", ^term),
          desc_nulls_last: w.tmdb_popularity
        ],
        limit: ^limit
    )
  end

  defp trigram_search(term, kinds, limit) do
    Repo.all(
      from w in Work,
        where: w.kind in ^kinds,
        where: fragment("? % ?", w.title, ^term),
        order_by: [desc: fragment("similarity(?, ?)", w.title, ^term)],
        limit: ^limit
    )
  end

  ## Ecriture

  @doc """
  Cree ou met a jour une oeuvre a partir de donnees TMDB.

  Upsert sur `(kind, tmdb_id)`, en **preservant** le slug et les compteurs
  communautaires : une resynchronisation TMDB ne doit ni casser une URL deja
  partagee, ni ecraser des donnees que TMDB ne connait pas.
  """
  def upsert_work(attrs) do
    attrs = Map.put_new_lazy(attrs, :slug, fn -> next_slug(attrs) end)

    %Work{}
    |> Work.changeset(attrs)
    |> Repo.insert(
      on_conflict:
        {:replace_all_except,
         [
           :id,
           :inserted_at,
           :slug,
           :smovie_rating_avg,
           :smovie_rating_count,
           :smovie_watch_count,
           :smovie_review_count
         ]},
      conflict_target: [:kind, :tmdb_id],
      returning: true
    )
  end

  @doc """
  Slug disponible pour une oeuvre a creer.
  """
  def next_slug(attrs) do
    attrs
    |> base_slug()
    |> Slug.unique(&slug_taken?/1)
  end

  defp base_slug(%{kind: kind} = attrs) when kind in [:movie, :tv_show],
    do: Slug.build(attrs[:title], attrs[:release_date])

  defp base_slug(%{kind: :season} = attrs),
    do: Slug.build_season(parent_slug(attrs), attrs[:season_number])

  defp base_slug(%{kind: :episode} = attrs) do
    Slug.build_episode(series_slug(attrs), attrs[:season_number], attrs[:episode_number])
  end

  defp base_slug(attrs), do: Slug.build(attrs[:title], attrs[:release_date])

  defp parent_slug(%{parent_id: parent_id}) when not is_nil(parent_id) do
    case Repo.get(Work, parent_id) do
      %Work{slug: slug} -> slug
      nil -> "serie"
    end
  end

  defp parent_slug(_attrs), do: "serie"

  # Un episode pend d'une saison, qui pend de la serie : son slug remonte de
  # deux crans pour ne pas repeter « saison-2 » devant « s02e07 ».
  defp series_slug(%{parent_id: parent_id}) when not is_nil(parent_id) do
    case Repo.get(Work, parent_id) do
      %Work{parent_id: series_id} when not is_nil(series_id) ->
        parent_slug(%{parent_id: series_id})

      %Work{slug: slug} ->
        slug

      nil ->
        "serie"
    end
  end

  defp series_slug(_attrs), do: "serie"

  defp slug_taken?(slug), do: Repo.exists?(from w in Work, where: w.slug == ^slug)

  @doc """
  Vrai si l'oeuvre merite une resynchronisation.

  Au-dela de deux ans apres la sortie, les metadonnees ne bougent plus : la
  fenetre passe de sept a trente jours pour epargner des appels inutiles.
  """
  def stale?(%Work{synced_at: nil}), do: true

  def stale?(%Work{synced_at: synced_at} = work) do
    DateTime.diff(DateTime.utc_now(), synced_at, :day) > sync_window_days(work)
  end

  defp sync_window_days(%Work{release_date: %Date{} = date}) do
    if Date.diff(Date.utc_today(), date) > 730, do: 30, else: 7
  end

  defp sync_window_days(%Work{}), do: 7

  @doc """
  Seuil de votes en dessous duquel la moyenne communautaire n'est pas affichee.
  """
  def min_votes, do: Config.trending_min_votes()
end
