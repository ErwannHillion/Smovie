defmodule Smovie.Catalog do
  @moduledoc """
  Le catalogue : films, series, saisons, episodes.

  Donnees de reference, partagees par tous les membres. Rien ici ne depend de
  qui regarde — ce qui distingue ce contexte de `Smovie.Library`, qui porte ce
  qu'un membre fait des oeuvres et n'est lisible que sous autorisation.
  """

  import Ecto.Query, warn: false

  alias Smovie.Catalog.Credit
  alias Smovie.Catalog.ExternalRating
  alias Smovie.Catalog.Genre
  alias Smovie.Catalog.Person
  alias Smovie.Catalog.Slug
  alias Smovie.Catalog.Sync.Importer
  alias Smovie.Catalog.Sync.Mapper
  alias Smovie.Catalog.Work
  alias Smovie.Catalog.WorkGenre
  alias Smovie.Catalog.WorkKind
  alias Smovie.Config
  alias Smovie.External.TMDB
  alias Smovie.Repo
  alias Smovie.Workers.FetchExternalRatingsWorker
  alias Smovie.Workers.SyncSeasonsWorker
  alias Smovie.Workers.SyncWorkWorker

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
  Recharge une oeuvre depuis la base.

  Les LiveViews en ont besoin apres une action qui modifie des compteurs ; le
  rechargement vit ici plutot que dans la vue, ou `Repo` n'a rien a faire.
  """
  def reload_work(%Work{id: id}), do: Repo.get(Work, id)

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
  def get_season(%Work{kind: :tv_show, id: id}, number) when is_integer(number) do
    Repo.get_by(Work, parent_id: id, kind: :season, season_number: number)
  end

  # Le numero vient de l'URL, donc de l'exterieur : un segment illisible doit
  # donner une absence, pas une exception.
  def get_season(%Work{kind: :tv_show} = show, number) when is_binary(number) do
    case Integer.parse(number) do
      {parsed, ""} -> get_season(show, parsed)
      _other -> nil
    end
  end

  def get_season(%Work{}, _number), do: nil

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

  @doc """
  Recherche locale completee par TMDB.

  Le catalogue local d'abord : il est instantane, et ce qu'on y trouve est
  deja enrichi des notes de la communaute. TMDB ne sert qu'a completer quand
  le local ne rend pas grand-chose — appeler TMDB systematiquement ajouterait
  une latence reseau a chaque frappe.

  Les resultats TMDB sont marques `imported: false` : l'interface doit pouvoir
  dire qu'une oeuvre n'est pas encore dans Smovie plutot que de faire croire
  a une fiche qui n'existe pas.
  """
  def search_everywhere(term, opts \\ []) do
    locaux = search(term, opts)
    seuil = Keyword.get(opts, :local_threshold, 5)

    if length(locaux) >= seuil do
      Enum.map(locaux, &%{work: &1, imported: true})
    else
      Enum.map(locaux, &%{work: &1, imported: true}) ++ remote_results(term, locaux, opts)
    end
  end

  defp remote_results(term, locaux, opts) do
    limit = Keyword.get(opts, :remote_limit, 10)
    connus = MapSet.new(locaux, &{&1.kind, &1.tmdb_id})

    case TMDB.search_multi(term, []) do
      {:ok, %{"results" => results}} ->
        results
        |> Enum.map(&Mapper.search_result_attrs/1)
        |> Enum.filter(&match?({:ok, _attrs}, &1))
        |> Enum.map(fn {:ok, attrs} -> attrs end)
        |> Enum.reject(&MapSet.member?(connus, {&1.kind, &1.tmdb_id}))
        |> Enum.take(limit)
        |> Enum.map(&%{work: &1, imported: false})

      _error ->
        # TMDB indisponible ne doit pas vider la page : les resultats locaux
        # restent affiches.
        []
    end
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

  ## Notes externes

  @doc """
  Remplace les notes externes d'une oeuvre.
  """
  def put_external_ratings(%Work{id: work_id}, rating_attrs) when is_list(rating_attrs) do
    Enum.map(rating_attrs, fn attrs ->
      %ExternalRating{}
      |> ExternalRating.changeset(Map.put(attrs, :work_id, work_id))
      |> Repo.insert(
        on_conflict: {:replace, [:score, :scale, :votes_count, :url, :fetched_at]},
        conflict_target: [:work_id, :source],
        returning: true
      )
    end)
  end

  @doc """
  Notes externes d'une oeuvre, indexees par source.
  """
  def external_ratings(%Work{id: work_id}) do
    Repo.all(from r in ExternalRating, where: r.work_id == ^work_id)
    |> Map.new(&{&1.source, &1})
  end

  @doc """
  Note presse a afficher, et sa source.

  Ordre de repli : IMDb, puis Metacritic, puis Rotten Tomatoes. L'etiquette
  dit toujours la source reelle — afficher une note TMDB sous le mot
  « presse » serait faux, et c'est la raison d'etre de ce tuple.
  """
  def press_rating(%Work{} = work), do: work |> external_ratings() |> pick_press()

  def press_rating(ratings) when is_map(ratings), do: pick_press(ratings)

  defp pick_press(ratings) do
    Enum.find_value([:imdb, :metacritic, :rotten_tomatoes], fn source ->
      case ratings[source] do
        nil -> nil
        rating -> {ExternalRating.label(source), ExternalRating.out_of_ten(rating)}
      end
    end)
  end

  @doc """
  Vrai si les notes presse de l'oeuvre meritent d'etre rafraichies.

  Un appel par oeuvre tous les sept jours au maximum : le palier gratuit
  d'OMDb plafonne a mille requetes par jour, et une note presse ne bouge pas
  d'un jour a l'autre.
  """
  def press_rating_stale?(%Work{imdb_id: nil}), do: false

  def press_rating_stale?(%Work{} = work) do
    case external_ratings(work) do
      ratings when ratings == %{} ->
        true

      ratings ->
        ratings
        |> Map.values()
        |> Enum.map(& &1.fetched_at)
        |> Enum.max(DateTime)
        |> then(&(DateTime.diff(DateTime.utc_now(), &1, :day) > 7))
    end
  end

  ## Genres, personnes et casting

  @doc """
  Cree ou met a jour des genres, et renvoie leurs enregistrements.
  """
  def upsert_genres(genre_attrs) when is_list(genre_attrs) do
    Enum.flat_map(genre_attrs, fn attrs ->
      case %Genre{} |> Genre.changeset(attrs) |> upsert_genre() do
        {:ok, genre} -> [genre]
        {:error, _changeset} -> []
      end
    end)
  end

  defp upsert_genre(changeset) do
    Repo.insert(changeset,
      on_conflict: {:replace, [:name, :slug, :updated_at]},
      conflict_target: :tmdb_id,
      returning: true
    )
  end

  @doc """
  Rattache une oeuvre a un ensemble de genres, en remplacant les precedents.

  Remplacement et non ajout : un genre retire chez TMDB doit disparaitre ici,
  sinon la fiche accumule des etiquettes que plus personne ne corrige.
  """
  def put_work_genres(%Work{id: work_id}, genres) when is_list(genres) do
    Repo.transaction(fn ->
      Repo.delete_all(from wg in WorkGenre, where: wg.work_id == ^work_id)

      entries = Enum.map(genres, &%{work_id: work_id, genre_id: &1.id})
      Repo.insert_all(WorkGenre, entries, on_conflict: :nothing)

      length(entries)
    end)
  end

  @doc """
  Genres d'une oeuvre, par ordre alphabetique.
  """
  def list_work_genres(%Work{id: work_id}) do
    Repo.all(
      from g in Genre,
        join: wg in WorkGenre,
        on: wg.genre_id == g.id,
        where: wg.work_id == ^work_id,
        order_by: g.name
    )
  end

  @doc """
  Cree ou met a jour une personne.
  """
  def upsert_person(attrs) do
    %Person{}
    |> Person.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:name, :profile_path, :known_for_department, :updated_at]},
      conflict_target: :tmdb_id,
      returning: true
    )
  end

  @doc """
  Remplace les participations d'une oeuvre.

  Remplacement plutot qu'ajout, pour la meme raison que les genres : un acteur
  retire d'un generique doit disparaitre de la fiche.
  """
  def put_work_credits(%Work{id: work_id}, credit_attrs) when is_list(credit_attrs) do
    Repo.transaction(fn ->
      Repo.delete_all(from c in Credit, where: c.work_id == ^work_id)

      credit_attrs
      |> Enum.map(&insert_credit(&1, work_id))
      |> Enum.count(&match?({:ok, _credit}, &1))
    end)
  end

  defp insert_credit(%{person: person_attrs} = attrs, work_id) do
    case upsert_person(person_attrs) do
      {:ok, person} ->
        attrs
        |> Map.drop([:person])
        |> Map.merge(%{work_id: work_id, person_id: person.id})
        |> then(&Credit.changeset(%Credit{}, &1))
        |> Repo.insert(on_conflict: :nothing)

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Interpretes d'une oeuvre, dans l'ordre du generique.
  """
  def list_cast(%Work{id: work_id}, opts \\ []) do
    limit = Keyword.get(opts, :limit, 12)

    Repo.all(
      from c in Credit,
        where: c.work_id == ^work_id and c.kind == :cast,
        order_by: [asc_nulls_last: c.display_order],
        limit: ^limit,
        preload: [:person]
    )
  end

  @doc """
  Equipe technique d'une oeuvre.
  """
  def list_crew(%Work{id: work_id}) do
    Repo.all(
      from c in Credit,
        where: c.work_id == ^work_id and c.kind == :crew,
        order_by: [asc: c.job],
        preload: [:person]
    )
  end

  @doc """
  Realisateurs d'une oeuvre.

  Une oeuvre peut en avoir plusieurs — les Wachowski, les Coen, les Daniels —
  et n'en afficher qu'un serait faux.
  """
  def list_directors(%Work{id: work_id}) do
    Repo.all(
      from c in Credit,
        join: p in assoc(c, :person),
        where: c.work_id == ^work_id and c.kind == :crew and c.job == "Director",
        order_by: p.name,
        select: p
    )
  end

  @doc """
  Recupere une oeuvre par slug, en l'important de TMDB si elle manque.

  L'oeuvre deja presente est rendue immediatement, et remise en file de
  rafraichissement si sa synchro a vieilli : la page s'affiche avec ce qu'on a
  plutot que d'attendre TMDB.
  """
  def fetch_work_by_slug(kind, slug) do
    case Repo.get_by(Work, slug: slug, kind: kind) do
      nil -> {:error, :not_found}
      work -> {:ok, refresh_if_stale(work)}
    end
  end

  @doc """
  Importe une oeuvre TMDB si elle n'est pas deja en base.

  Appele au clic sur un resultat de recherche venu de TMDB.
  """
  def import_work(kind, tmdb_id) when is_binary(kind) do
    case WorkKind.cast(kind) do
      {:ok, parsed} -> import_work(parsed, tmdb_id)
      :error -> {:error, :invalid_kind}
    end
  end

  # Les deux valeurs viennent du DOM : leur conversion vit ici, ou une entree
  # trafiquee donne une erreur plutot qu'une exception.
  def import_work(kind, tmdb_id) when is_binary(tmdb_id) do
    case Integer.parse(tmdb_id) do
      {parsed, ""} -> import_work(kind, parsed)
      _other -> {:error, :invalid_tmdb_id}
    end
  end

  def import_work(kind, tmdb_id) do
    case get_work_by_tmdb_id(kind, tmdb_id) do
      nil -> Importer.import_work(kind, tmdb_id)
      work -> {:ok, refresh_if_stale(work)}
    end
  end

  @doc """
  Saisons d'une serie, importees au premier affichage.

  Un appel TMDB par saison ramene tous ses episodes d'un coup : importer les
  episodes un par un multiplierait les appels par vingt.
  """
  def fetch_seasons(%Work{kind: :tv_show} = show) do
    case list_seasons(show) do
      [] -> enqueue_seasons(show)
      seasons -> seasons
    end
  end

  # Importer dans le cycle de requete ferait attendre un appel TMDB par
  # saison : une serie de dix saisons bloquerait la page dix fois.
  defp enqueue_seasons(show) do
    SyncSeasonsWorker.enqueue(show)
    []
  end

  @doc """
  Episodes d'une saison, importes si la saison est vide.
  """
  def fetch_episodes(%Work{kind: :season} = season) do
    case list_episodes(season) do
      [] -> import_and_list_episodes(season)
      episodes -> episodes
    end
  end

  defp import_and_list_episodes(season) do
    case Repo.get(Work, season.parent_id) do
      %Work{kind: :tv_show} = show ->
        Importer.import_season(show, season.season_number)
        list_episodes(season)

      _other ->
        []
    end
  end

  defp refresh_if_stale(%Work{kind: kind} = work) when kind in [:movie, :tv_show] do
    if stale?(work), do: SyncWorkWorker.enqueue(kind, work.tmdb_id)
    if press_rating_stale?(work), do: FetchExternalRatingsWorker.enqueue(work)
    work
  end

  defp refresh_if_stale(work), do: work

  @doc """
  Seuil de votes en dessous duquel la moyenne communautaire n'est pas affichee.
  """
  def min_votes, do: Config.trending_min_votes()
end
