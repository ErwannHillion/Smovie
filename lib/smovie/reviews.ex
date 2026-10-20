defmodule Smovie.Reviews do
  @moduledoc """
  Les critiques : redaction, lecture, classement.

  La visibilite d'une review suit un principe simple : **la note compte
  toujours dans la moyenne, le texte pas toujours**. Une review privee est un
  texte prive, pas un vote retire — la distinction change les requetes de bout
  en bout.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Smovie.Accounts.Scope
  alias Smovie.Accounts.User
  alias Smovie.Catalog.Work
  alias Smovie.Config
  alias Smovie.Library
  alias Smovie.Repo
  alias Smovie.Reviews.Review
  alias Smovie.Social

  ## Lecture

  @doc """
  Review d'un membre sur une oeuvre, ou `nil`.
  """
  def get_user_review(%Scope{user: %User{id: user_id}}, %Work{id: work_id}) do
    Repo.one(
      from r in Review,
        where: r.user_id == ^user_id and r.work_id == ^work_id,
        preload: [:user, :work]
    )
  end

  def get_user_review(nil, %Work{}), do: nil

  @doc """
  Review par identifiant, avec son auteur et son oeuvre, ou `nil`.
  """
  def get_review(id) when is_integer(id) do
    Repo.one(from r in Review, where: r.id == ^id, preload: [:user, :work])
  end

  def get_review(id) when is_binary(id) do
    case Integer.parse(id) do
      {parsed, ""} -> get_review(parsed)
      _other -> nil
    end
  end

  @doc """
  Vrai si `scope` peut lire cette review.

  Une review `followers` n'est lisible que par un abonne de son auteur ; une
  review `private` seulement par lui.
  """
  def visible?(scope, review)

  def visible?(%Scope{user: %User{id: id}}, %Review{user_id: id}), do: true
  def visible?(_scope, %Review{visibility: :public}), do: true
  def visible?(_scope, %Review{visibility: :private}), do: false

  def visible?(%Scope{} = scope, %Review{visibility: :followers} = review) do
    Social.following?(scope, %User{id: review.user_id})
  end

  def visible?(_scope, %Review{}), do: false

  @doc """
  Les reviews populaires d'une oeuvre.

  Le plancher de longueur ecarte les « bof » d'une ligne qui ont pris deux
  likes ; l'index unique (user_id, work_id) garantit cinq auteurs differents.
  """
  def list_popular_for_work(%Work{id: work_id}, opts \\ []) do
    limit = Keyword.get(opts, :limit, Config.popular_reviews_limit())
    min_length = Config.reviews_min_body_length()

    Repo.all(
      from r in Review,
        where: r.work_id == ^work_id,
        where: r.visibility == :public,
        where: fragment("length(?) >= ?", r.body, ^min_length),
        order_by: [desc: r.likes_count, desc: r.published_at],
        limit: ^limit,
        preload: [:user]
    )
  end

  @doc """
  Reviews d'un membre, de la plus recente a la plus ancienne.
  """
  def list_by_user(scope, %User{} = author, opts \\ []) do
    limit = Keyword.get(opts, :limit, 30)

    from(r in Review,
      where: r.user_id == ^author.id,
      order_by: [desc: r.published_at],
      limit: ^limit,
      preload: [:work, :user]
    )
    |> restrict_visibility(scope, author)
    |> Repo.all()
  end

  # Un membre voit toutes ses reviews ; un abonne voit en plus les `followers`.
  defp restrict_visibility(query, %Scope{user: %User{id: id}}, %User{id: id}), do: query

  defp restrict_visibility(query, scope, author) do
    if Social.following?(scope, author) do
      from r in query, where: r.visibility in [:public, :followers]
    else
      from r in query, where: r.visibility == :public
    end
  end

  @doc """
  Nombre de reviews publiees par un membre.
  """
  def count_by_user(%User{id: user_id}) do
    Repo.aggregate(from(r in Review, where: r.user_id == ^user_id), :count)
  end

  ## Ecriture

  @doc """
  Changeset de review, pour les formulaires.
  """
  def change_review(%Review{} = review, attrs \\ %{}) do
    Review.changeset(review, attrs)
  end

  @doc """
  Publie ou met a jour la review d'un membre sur une oeuvre.

  La note courante de l'auteur y est recopiee, et l'oeuvre est marquee vue :
  on n'ecrit pas sur un film qu'on n'a pas vu, et demander une confirmation
  separee serait un geste de plus pour une information deja donnee.
  """
  def publish(%Scope{user: %User{id: user_id}} = scope, %Work{} = work, attrs) do
    attrs =
      attrs
      |> normalize()
      |> Map.merge(%{
        "user_id" => user_id,
        "work_id" => work.id,
        "rating_value" => rating_value(scope, work, attrs)
      })

    Multi.new()
    |> Multi.insert(
      :review,
      Review.changeset(%Review{}, attrs),
      on_conflict:
        {:replace,
         [:body, :contains_spoilers, :rating_value, :watched_on, :visibility, :updated_at]},
      conflict_target: [:user_id, :work_id],
      returning: true
    )
    |> Multi.run(:count, fn _repo, _changes -> refresh_review_count(work.id) end)
    |> Repo.transaction()
    |> case do
      {:ok, %{review: review}} ->
        mark_watched_if_needed(scope, work)
        {:ok, review}

      {:error, _step, changeset, _changes} ->
        {:error, changeset}
    end
  end

  def publish(%Scope{}, %Work{}, _attrs), do: {:error, :unauthorized}

  @doc """
  Supprime une review. Seul son auteur le peut.
  """
  def delete(%Scope{user: %User{id: user_id}}, %Review{user_id: user_id} = review) do
    case Repo.delete(review) do
      {:ok, deleted} ->
        refresh_review_count(review.work_id)
        {:ok, deleted}

      error ->
        error
    end
  end

  def delete(%Scope{}, %Review{}), do: {:error, :unauthorized}

  # La note affichee sous une review est celle de l'auteur au moment de la
  # publication : on la recopie plutot que de la joindre, pour qu'une note
  # revue plus tard ne reecrive pas l'histoire.
  defp rating_value(scope, work, attrs) do
    case Map.get(normalize(attrs), "rating_value") do
      nil -> scope |> Library.get_rating(work) |> rating_or_nil()
      value -> value
    end
  end

  defp rating_or_nil(nil), do: nil
  defp rating_or_nil(rating), do: rating.value

  defp mark_watched_if_needed(scope, work) do
    unless Library.watched?(scope, work), do: Library.mark_watched(scope, work)
    :ok
  end

  defp refresh_review_count(work_id) do
    count =
      Repo.aggregate(
        from(r in Review, where: r.work_id == ^work_id and r.visibility == :public),
        :count
      )

    Repo.update_all(from(w in Work, where: w.id == ^work_id),
      set: [smovie_review_count: count]
    )

    {:ok, count}
  end

  # Les formulaires envoient des cles binaires, le code appelant des atomes.
  defp normalize(attrs) do
    Map.new(attrs, fn {key, value} -> {to_string(key), value} end)
  end
end
