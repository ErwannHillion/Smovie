defmodule Smovie.Library do
  @moduledoc """
  Ce qu'un membre fait des oeuvres : notes, journal, watchlist, likes.

  Contrairement a `Smovie.Catalog`, tout ici depend de qui regarde : chaque
  fonction d'ecriture prend le `Scope` en premier argument, et l'autorisation
  se filtre dans la signature.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Smovie.Accounts.Scope
  alias Smovie.Accounts.User
  alias Smovie.Catalog.Work
  alias Smovie.Catalog.WorkGenre
  alias Smovie.Config
  alias Smovie.Library.Rating
  alias Smovie.Library.RatingStats
  alias Smovie.Library.WatchEntry
  alias Smovie.Library.WatchlistItem
  alias Smovie.Library.WorkLike
  alias Smovie.Repo

  @pubsub Smovie.PubSub

  ## Notes

  @doc """
  Note d'un membre sur une oeuvre, ou `nil`.
  """
  def get_rating(%Scope{user: %User{id: user_id}}, %Work{id: work_id}) do
    Repo.get_by(Rating, user_id: user_id, work_id: work_id)
  end

  def get_rating(nil, %Work{}), do: nil

  @doc """
  Notes d'un membre sur une liste d'oeuvres, indexees par `work_id`.

  Une requete pour toute une saison plutot qu'une par episode : sans cela, une
  page de vingt episodes declencherait vingt requetes.
  """
  def ratings_by_work_id(%Scope{user: %User{id: user_id}}, works) when is_list(works) do
    ids = Enum.map(works, & &1.id)

    from(r in Rating, where: r.user_id == ^user_id and r.work_id in ^ids)
    |> Repo.all()
    |> Map.new(&{&1.work_id, &1})
  end

  def ratings_by_work_id(nil, _works), do: %{}

  @doc """
  Pose ou remplace la note d'un membre.

  La moyenne de l'oeuvre est recalculee dans la **meme transaction** : une
  moyenne recalculee apres coup laisserait une fenetre ou la fiche affiche un
  chiffre faux, et un plantage entre les deux la figerait indefiniment.
  """
  def rate_work(%Scope{user: %User{id: user_id}} = scope, %Work{} = work, value) do
    Multi.new()
    |> Multi.insert(
      :rating,
      Rating.changeset(%Rating{}, %{user_id: user_id, work_id: work.id, value: value}),
      on_conflict: {:replace, [:value, :rated_at, :updated_at]},
      conflict_target: [:user_id, :work_id],
      returning: true
    )
    |> Multi.run(:work, fn _repo, _changes -> recompute_rating(work.id) end)
    |> Repo.transaction()
    |> case do
      {:ok, %{rating: rating, work: work}} ->
        broadcast_rating(scope, work)
        {:ok, rating}

      {:error, _step, changeset, _changes} ->
        {:error, changeset}
    end
  end

  def rate_work(%Scope{}, %Work{}, _value), do: {:error, :unauthorized}

  @doc """
  Retire la note d'un membre.
  """
  def unrate_work(%Scope{user: %User{id: user_id}} = scope, %Work{id: work_id}) do
    Multi.new()
    |> Multi.delete_all(
      :rating,
      from(r in Rating, where: r.user_id == ^user_id and r.work_id == ^work_id)
    )
    |> Multi.run(:work, fn _repo, _changes -> recompute_rating(work_id) end)
    |> Repo.transaction()
    |> case do
      {:ok, %{rating: {0, _}}} ->
        {:error, :not_rated}

      {:ok, %{work: updated}} ->
        broadcast_rating(scope, updated)
        :ok

      {:error, _step, reason, _changes} ->
        {:error, reason}
    end
  end

  def unrate_work(%Scope{}, %Work{}), do: {:error, :unauthorized}

  @doc """
  Bascule la note : reposer la meme valeur la retire.

  Un geste unique pour poser, corriger et retirer — sur un ecran tactile, un
  bouton « retirer la note » separe serait une cible de plus a atteindre.
  """
  def toggle_rating(%Scope{} = scope, %Work{} = work, value) do
    half_stars = cast_value(value)

    case get_rating(scope, work) do
      %Rating{value: ^half_stars} -> unrate_work(scope, work)
      _other -> rate_work(scope, work, half_stars)
    end
  end

  # La valeur arrive en chaine depuis le DOM. La conversion vit ici, dans le
  # contexte, et non dans la LiveView : une valeur illisible devient `nil`, que
  # le changeset refusera proprement, la ou String.to_integer/1 leverait.
  defp cast_value(value) when is_integer(value), do: value

  defp cast_value(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _other -> nil
    end
  end

  defp cast_value(_value), do: nil

  @doc """
  Recalcule la moyenne bayesienne d'une oeuvre.

  Formule : `(n / (n + C)) * m + (C / (n + C)) * m_global`, ou `C` est le poids
  de l'a priori en nombre de votes.

  Une moyenne brute placerait un film note 5 etoiles par une seule personne
  au-dessus d'un film note 4,6 par huit cents. Sur une plateforme jeune, ou la
  plupart des oeuvres ont deux ou trois notes, un classement par moyenne brute
  n'est que du bruit.
  """
  def recompute_rating(work_id) do
    prior = Config.ratings_prior_votes()
    global = global_average()

    {count, sum} = rating_totals(work_id)

    attrs =
      if count == 0 do
        %{smovie_rating_avg: nil, smovie_rating_count: 0}
      else
        raw = Decimal.div(Decimal.new(sum), Decimal.new(count))
        %{smovie_rating_avg: bayesian(raw, count, prior, global), smovie_rating_count: count}
      end

    {1, [work]} =
      from(w in Work, where: w.id == ^work_id, select: w)
      |> Repo.update_all(set: Map.to_list(attrs))

    {:ok, work}
  end

  defp rating_totals(work_id) do
    from(r in Rating,
      where: r.work_id == ^work_id,
      select: {count(r.id), coalesce(sum(r.value), 0)}
    )
    |> Repo.one()
  end

  defp bayesian(raw_average, count, prior, global_average) do
    total = Decimal.new(count + prior)
    own = Decimal.mult(Decimal.div(Decimal.new(count), total), raw_average)
    borrowed = Decimal.mult(Decimal.div(Decimal.new(prior), total), global_average)

    own |> Decimal.add(borrowed) |> Decimal.round(2)
  end

  @doc """
  Moyenne de la plateforme, qui sert d'a priori.
  """
  def global_average do
    case Repo.one(from s in RatingStats, select: s.global_average) do
      nil -> Decimal.new("6.80")
      average -> average
    end
  end

  @doc """
  Rafraichit la moyenne de la plateforme.
  """
  def refresh_global_average do
    {count, average} =
      from(r in Rating, select: {count(r.id), avg(r.value)})
      |> Repo.one()

    average = if count == 0, do: Decimal.new("6.80"), else: Decimal.round(average, 2)

    Repo.update_all(RatingStats,
      set: [
        global_average: average,
        ratings_count: count,
        computed_at: DateTime.utc_now(:second)
      ]
    )

    {:ok, average}
  end

  @doc """
  Nombre de notes posees par un membre.
  """
  def rating_count(%User{id: user_id}) do
    Repo.aggregate(from(r in Rating, where: r.user_id == ^user_id), :count)
  end

  @doc """
  Repartition des notes d'un membre, de 1 a 10 demi-etoiles.

  Les crans sans note sont presents a zero : un histogramme a trous se lirait
  de travers.
  """
  def rating_histogram(%User{id: user_id}) do
    counts =
      from(r in Rating,
        where: r.user_id == ^user_id,
        group_by: r.value,
        select: {r.value, count(r.id)}
      )
      |> Repo.all()
      |> Map.new()

    Map.new(1..10, &{&1, Map.get(counts, &1, 0)})
  end

  ## Journal de visionnage

  @doc """
  Marque une oeuvre comme vue.

  Une seconde seance le meme jour n'en cree pas une deuxieme : c'est presque
  toujours un double clic, pas deux visionnages. Un re-visionnage un autre
  jour s'ajoute en revanche a l'historique.

  Marquer vu retire l'oeuvre de la watchlist : elle n'est plus a voir.
  """
  def mark_watched(scope, work, opts \\ [])

  def mark_watched(%Scope{user: %User{id: user_id}} = scope, %Work{} = work, opts) do
    watched_on = Keyword.get(opts, :watched_on, Date.utc_today())
    rewatch = watched_count(scope, work) > 0

    attrs = %{
      user_id: user_id,
      work_id: work.id,
      watched_on: watched_on,
      rewatch: rewatch
    }

    %WatchEntry{}
    |> WatchEntry.changeset(attrs)
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:user_id, :work_id, :watched_on])
    |> case do
      {:ok, entry} ->
        bump_watch_count(work.id)
        drop_from_watchlist(scope, work)
        {:ok, entry}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def mark_watched(%Scope{}, %Work{}, _opts), do: {:error, :unauthorized}

  @doc """
  Retire une seance. Sans date, retire la plus recente.
  """
  def unmark_watched(scope, work, opts \\ [])

  def unmark_watched(%Scope{user: %User{id: user_id}}, %Work{id: work_id}, opts) do
    query =
      case Keyword.get(opts, :watched_on) do
        nil ->
          from(e in WatchEntry, where: e.user_id == ^user_id and e.work_id == ^work_id)

        date ->
          from(e in WatchEntry,
            where: e.user_id == ^user_id and e.work_id == ^work_id and e.watched_on == ^date
          )
      end

    case Repo.delete_all(latest_only(query, opts)) do
      {0, _} ->
        {:error, :not_watched}

      {_count, _} ->
        bump_watch_count(work_id)
        :ok
    end
  end

  # Sans date, on ne supprime que la seance la plus recente : effacer tout
  # l'historique d'un clic serait irreversible et jamais ce qu'on veut.
  defp latest_only(query, opts) do
    case Keyword.get(opts, :watched_on) do
      nil ->
        from(e in WatchEntry,
          where:
            e.id in subquery(
              from(q in query, order_by: [desc: q.watched_on, desc: q.id], limit: 1, select: q.id)
            )
        )

      _date ->
        query
    end
  end

  @doc """
  Vrai si le membre a deja vu l'oeuvre.
  """
  def watched?(%Scope{} = scope, %Work{} = work), do: watched_count(scope, work) > 0
  def watched?(nil, %Work{}), do: false

  @doc """
  Nombre de seances d'un membre sur une oeuvre.
  """
  def watched_count(%Scope{user: %User{id: user_id}}, %Work{id: work_id}) do
    Repo.aggregate(
      from(e in WatchEntry, where: e.user_id == ^user_id and e.work_id == ^work_id),
      :count
    )
  end

  def watched_count(nil, %Work{}), do: 0

  @doc """
  Journal d'un membre, de la seance la plus recente a la plus ancienne.
  """
  def list_watch_entries(%User{id: user_id}, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    Repo.all(
      from e in WatchEntry,
        where: e.user_id == ^user_id,
        order_by: [desc: e.watched_on, desc: e.id],
        limit: ^limit,
        preload: [:work]
    )
  end

  @doc """
  Oeuvres vues par un membre, une seule fois chacune.
  """
  def list_watched_works(%User{id: user_id}, opts \\ []) do
    kind = Keyword.get(opts, :kind, :movie)
    limit = Keyword.get(opts, :limit, 60)

    Repo.all(
      from w in Work,
        join: e in WatchEntry,
        on: e.work_id == w.id,
        where: e.user_id == ^user_id and w.kind == ^kind,
        group_by: w.id,
        order_by: [desc: max(e.watched_on)],
        limit: ^limit
    )
  end

  @doc """
  Minutes de visionnage cumulees d'un membre.

  Les episodes comptent comme les films : c'est du temps passe devant un
  ecran, et l'exclure donnerait un chiffre faux a qui regarde surtout des
  series.
  """
  def watched_minutes(%User{id: user_id}) do
    from(e in WatchEntry,
      join: w in Work,
      on: w.id == e.work_id,
      where: e.user_id == ^user_id,
      select: coalesce(sum(w.runtime), 0)
    )
    |> Repo.one()
  end

  # Nombre de spectateurs distincts, et non de seances : deux visionnages par
  # la meme personne ne font pas deux spectateurs.
  defp bump_watch_count(work_id) do
    count =
      from(e in WatchEntry, where: e.work_id == ^work_id, select: count(e.user_id, :distinct))
      |> Repo.one()

    Repo.update_all(from(w in Work, where: w.id == ^work_id),
      set: [smovie_watch_count: count]
    )
  end

  # Marquer vu retire de la watchlist : l'oeuvre n'est plus a voir. On ignore
  # le cas ou elle n'y etait pas, qui est le plus frequent.
  defp drop_from_watchlist(%Scope{user: %User{id: user_id}}, %Work{id: work_id}) do
    Repo.delete_all(
      from i in WatchlistItem, where: i.user_id == ^user_id and i.work_id == ^work_id
    )

    :ok
  end

  ## Watchlist

  @doc """
  Ajoute une oeuvre a la liste a voir.

  Refuse une saison ou un episode : on ne met pas un episode « a voir », on
  reprend une serie la ou on l'a laissee.
  """
  def add_to_watchlist(scope, work, attrs \\ %{})

  def add_to_watchlist(%Scope{user: %User{id: user_id}}, %Work{kind: kind} = work, attrs)
      when kind in [:movie, :tv_show] do
    %WatchlistItem{}
    |> WatchlistItem.changeset(Map.merge(attrs, %{user_id: user_id, work_id: work.id}))
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:user_id, :work_id])
  end

  def add_to_watchlist(%Scope{}, %Work{}, _attrs), do: {:error, :not_watchlistable}

  @doc """
  Retire une oeuvre de la liste a voir.
  """
  def remove_from_watchlist(%Scope{user: %User{id: user_id}}, %Work{id: work_id}) do
    case Repo.delete_all(
           from i in WatchlistItem, where: i.user_id == ^user_id and i.work_id == ^work_id
         ) do
      {0, _} -> {:error, :not_in_watchlist}
      {_count, _} -> :ok
    end
  end

  @doc """
  Bascule la presence d'une oeuvre dans la liste a voir.
  """
  def toggle_watchlist(%Scope{} = scope, %Work{} = work) do
    if in_watchlist?(scope, work) do
      remove_from_watchlist(scope, work)
      {:ok, :removed}
    else
      case add_to_watchlist(scope, work) do
        {:ok, _item} -> {:ok, :added}
        error -> error
      end
    end
  end

  @doc """
  Vrai si l'oeuvre est dans la liste a voir du membre.
  """
  def in_watchlist?(%Scope{user: %User{id: user_id}}, %Work{id: work_id}) do
    Repo.exists?(from i in WatchlistItem, where: i.user_id == ^user_id and i.work_id == ^work_id)
  end

  def in_watchlist?(nil, %Work{}), do: false

  @doc """
  Liste a voir d'un membre.

  Tris acceptes : `:added` (defaut), `:release`, `:rating`, `:runtime`,
  `:title`. Un tri inconnu retombe sur la date d'ajout plutot que de lever :
  l'ordre vient de l'URL, donc de l'exterieur.
  """
  def list_watchlist(%User{id: user_id}, opts \\ []) do
    sort = Keyword.get(opts, :sort, :added)
    kind = Keyword.get(opts, :kind)
    genre_id = Keyword.get(opts, :genre_id)
    limit = Keyword.get(opts, :limit, 60)

    from(i in WatchlistItem,
      join: w in Work,
      on: w.id == i.work_id,
      where: i.user_id == ^user_id,
      limit: ^limit,
      select: w
    )
    |> filter_kind(kind)
    |> filter_genre(genre_id)
    |> sort_watchlist(sort)
    |> Repo.all()
  end

  defp filter_kind(query, nil), do: query
  defp filter_kind(query, kind), do: from([_i, w] in query, where: w.kind == ^kind)

  defp filter_genre(query, nil), do: query

  defp filter_genre(query, genre_id) do
    from([_i, w] in query,
      join: wg in WorkGenre,
      on: wg.work_id == w.id,
      where: wg.genre_id == ^genre_id
    )
  end

  defp sort_watchlist(query, :release),
    do: from([_i, w] in query, order_by: [desc_nulls_last: w.release_date])

  defp sort_watchlist(query, :rating),
    do: from([_i, w] in query, order_by: [desc_nulls_last: w.smovie_rating_avg])

  defp sort_watchlist(query, :runtime),
    do: from([_i, w] in query, order_by: [asc_nulls_last: w.runtime])

  defp sort_watchlist(query, :title), do: from([_i, w] in query, order_by: [asc: w.title])

  # Second critere sur l'identifiant : `inserted_at` est a la seconde, et deux
  # ajouts dans la meme seconde sortiraient dans un ordre arbitraire.
  defp sort_watchlist(query, _added),
    do: from([i, _w] in query, order_by: [desc: i.inserted_at, desc: i.id])

  @doc """
  Nombre d'oeuvres dans la liste a voir.
  """
  def watchlist_count(%User{id: user_id}) do
    Repo.aggregate(from(i in WatchlistItem, where: i.user_id == ^user_id), :count)
  end

  @doc """
  Duree totale de la liste a voir, en minutes.
  """
  def watchlist_minutes(%User{id: user_id}) do
    from(i in WatchlistItem,
      join: w in Work,
      on: w.id == i.work_id,
      where: i.user_id == ^user_id,
      select: coalesce(sum(w.runtime), 0)
    )
    |> Repo.one()
  end

  ## Progression dans une serie

  @doc """
  Progression d'un membre sur une saison : episodes vus sur total.

  Les deux chiffres sont renvoyes ensemble : « 7 vus » seul ne dit rien, et le
  total seul ne dit pas ou on en est.
  """
  def season_progress(%Scope{user: %User{id: user_id}}, %Work{kind: :season, id: season_id}) do
    total =
      Repo.aggregate(
        from(w in Work, where: w.parent_id == ^season_id and w.kind == :episode),
        :count
      )

    watched =
      from(e in WatchEntry,
        join: w in Work,
        on: w.id == e.work_id,
        where: e.user_id == ^user_id and w.parent_id == ^season_id and w.kind == :episode,
        select: count(e.work_id, :distinct)
      )
      |> Repo.one()

    %{watched: watched, total: total}
  end

  def season_progress(nil, %Work{kind: :season, id: season_id}) do
    total =
      Repo.aggregate(
        from(w in Work, where: w.parent_id == ^season_id and w.kind == :episode),
        :count
      )

    %{watched: 0, total: total}
  end

  @doc """
  Progression sur plusieurs saisons, indexee par identifiant de saison.

  Une requete pour toute la serie plutot qu'une par saison.
  """
  def season_progress_by_id(%Scope{user: %User{id: user_id}}, seasons) when is_list(seasons) do
    ids = Enum.map(seasons, & &1.id)

    totals =
      from(w in Work,
        where: w.parent_id in ^ids and w.kind == :episode,
        group_by: w.parent_id,
        select: {w.parent_id, count(w.id)}
      )
      |> Repo.all()
      |> Map.new()

    watched =
      from(e in WatchEntry,
        join: w in Work,
        on: w.id == e.work_id,
        where: e.user_id == ^user_id and w.parent_id in ^ids and w.kind == :episode,
        group_by: w.parent_id,
        select: {w.parent_id, count(e.work_id, :distinct)}
      )
      |> Repo.all()
      |> Map.new()

    Map.new(ids, fn id ->
      {id, %{watched: Map.get(watched, id, 0), total: Map.get(totals, id, 0)}}
    end)
  end

  def season_progress_by_id(nil, seasons) when is_list(seasons) do
    ids = Enum.map(seasons, & &1.id)

    totals =
      from(w in Work,
        where: w.parent_id in ^ids and w.kind == :episode,
        group_by: w.parent_id,
        select: {w.parent_id, count(w.id)}
      )
      |> Repo.all()
      |> Map.new()

    Map.new(ids, &{&1, %{watched: 0, total: Map.get(totals, &1, 0)}})
  end

  @doc """
  Progression sur toute une serie.
  """
  def show_progress(scope, %Work{kind: :tv_show} = show) do
    show
    |> Smovie.Catalog.list_seasons()
    |> then(&season_progress_by_id(scope, &1))
    |> Map.values()
    |> Enum.reduce(%{watched: 0, total: 0}, fn progress, acc ->
      %{watched: acc.watched + progress.watched, total: acc.total + progress.total}
    end)
  end

  ## Coups de coeur

  @doc """
  Bascule le coup de coeur d'un membre sur une oeuvre.
  """
  def toggle_like(%Scope{user: %User{id: user_id}}, %Work{id: work_id}) do
    query = from(l in WorkLike, where: l.user_id == ^user_id and l.work_id == ^work_id)

    case Repo.delete_all(query) do
      {0, _} -> insert_like(user_id, work_id)
      {_count, _} -> {:ok, :unliked}
    end
  end

  def toggle_like(%Scope{}, %Work{}), do: {:error, :unauthorized}

  defp insert_like(user_id, work_id) do
    %WorkLike{}
    |> WorkLike.changeset(%{user_id: user_id, work_id: work_id})
    |> Repo.insert()
    |> case do
      {:ok, _like} -> {:ok, :liked}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Vrai si le membre a aime l'oeuvre.
  """
  def liked?(%Scope{user: %User{id: user_id}}, %Work{id: work_id}) do
    Repo.exists?(from l in WorkLike, where: l.user_id == ^user_id and l.work_id == ^work_id)
  end

  def liked?(nil, %Work{}), do: false

  @doc """
  Sujet PubSub des notes d'une oeuvre.
  """
  def rating_topic(%Work{id: work_id}), do: "work:#{work_id}:ratings"

  defp broadcast_rating(_scope, work) do
    Phoenix.PubSub.broadcast(@pubsub, rating_topic(work), {:rating_updated, work})
  end
end
