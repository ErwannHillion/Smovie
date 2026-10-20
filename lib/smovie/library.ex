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
  alias Smovie.Config
  alias Smovie.Library.Rating
  alias Smovie.Library.RatingStats
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
    case get_rating(scope, work) do
      %Rating{value: ^value} -> unrate_work(scope, work)
      _other -> rate_work(scope, work, value)
    end
  end

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

  @doc """
  Sujet PubSub des notes d'une oeuvre.
  """
  def rating_topic(%Work{id: work_id}), do: "work:#{work_id}:ratings"

  defp broadcast_rating(_scope, work) do
    Phoenix.PubSub.broadcast(@pubsub, rating_topic(work), {:rating_updated, work})
  end
end
