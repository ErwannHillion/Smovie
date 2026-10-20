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
  alias Smovie.Reviews.ReviewComment
  alias Smovie.Reviews.ReviewLike
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
  Recharge une review avec son auteur et son oeuvre.
  """
  def reload(%Review{id: id}), do: get_review(id)

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
  Reviews populaires de la plateforme.

  Classer par likes seuls figerait la page sur les reviews anciennes : les
  plus likees de tous les temps le resteraient indefiniment. On applique donc
  une decote de graviteempruntee a Hacker News :

      score = (likes + 2 x commentaires) / (heures + 2) ^ 1.5

  Les commentaires comptent double : ils signalent une review qui fait debat,
  ce qu'un like ne dit pas.

  Le calcul se fait a la requete sur une fenetre courte — le volume y reste
  faible, une vue materialisee serait de la machinerie pour rien.
  """
  def list_popular(opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    days = Keyword.get(opts, :days, 14)
    min_length = Config.reviews_min_body_length()
    since = DateTime.add(DateTime.utc_now(), -days, :day)

    Repo.all(
      from r in Review,
        where: r.visibility == :public,
        where: r.published_at > ^since,
        where: fragment("length(?) >= ?", r.body, ^min_length),
        order_by: [
          desc:
            fragment(
              "(? + 2 * ?) / power(EXTRACT(EPOCH FROM (now() - ?)) / 3600.0 + 2, 1.5)",
              r.likes_count,
              r.comments_count,
              r.published_at
            )
        ],
        limit: ^limit,
        preload: [:user, :work]
    )
  end

  @doc """
  Reviews les plus recentes.
  """
  def list_recent(opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    Repo.all(
      from r in Review,
        where: r.visibility == :public,
        order_by: [desc: r.published_at],
        limit: ^limit,
        preload: [:user, :work]
    )
  end

  @doc """
  Reviews des comptes suivis.

  Les reviews reservees aux abonnes y entrent : on suit precisement ces
  comptes, donc on en est abonne.
  """
  def list_from_following(%Scope{} = scope, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    ids = Social.following_ids(scope)

    if ids == [] do
      []
    else
      Repo.all(
        from r in Review,
          where: r.user_id in ^ids,
          where: r.visibility in [:public, :followers],
          order_by: [desc: r.published_at],
          limit: ^limit,
          preload: [:user, :work]
      )
    end
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
        Social.record(scope, :reviewed, %{work_id: work.id, review_id: review.id})
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

  ## Likes

  @doc """
  Bascule le like d'un membre sur une review.

  Le compteur est mis a jour dans la meme transaction : un compteur recalcule
  apres coup se desynchronise au premier plantage, et c'est precisement le
  chiffre qui classe les reviews populaires.
  """
  def toggle_like(%Scope{user: %User{id: user_id}}, %Review{id: review_id}) do
    query = from l in ReviewLike, where: l.user_id == ^user_id and l.review_id == ^review_id

    Multi.new()
    |> Multi.run(:toggle, fn repo, _changes ->
      case repo.delete_all(query) do
        {0, _} -> insert_like(repo, user_id, review_id)
        {_count, _} -> {:ok, :unliked}
      end
    end)
    |> Multi.run(:count, fn repo, _changes -> refresh_like_count(repo, review_id) end)
    |> Repo.transaction()
    |> case do
      {:ok, %{toggle: :liked}} ->
        Social.notify(review_id_owner(review_id), user_id, :review_liked, %{review_id: review_id})
        {:ok, :liked}

      {:ok, %{toggle: result}} ->
        {:ok, result}

      {:error, _step, reason, _changes} ->
        {:error, reason}
    end
  end

  def toggle_like(%Scope{}, %Review{}), do: {:error, :unauthorized}

  defp insert_like(repo, user_id, review_id) do
    %ReviewLike{}
    |> ReviewLike.changeset(%{user_id: user_id, review_id: review_id})
    |> repo.insert()
    |> case do
      {:ok, _like} -> {:ok, :liked}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp review_id_owner(review_id) do
    Repo.one(from r in Review, where: r.id == ^review_id, select: r.user_id)
  end

  defp refresh_like_count(repo, review_id) do
    count = repo.aggregate(from(l in ReviewLike, where: l.review_id == ^review_id), :count)

    repo.update_all(from(r in Review, where: r.id == ^review_id), set: [likes_count: count])

    {:ok, count}
  end

  @doc """
  Vrai si le membre a like cette review.
  """
  def liked?(%Scope{user: %User{id: user_id}}, %Review{id: review_id}) do
    Repo.exists?(from l in ReviewLike, where: l.user_id == ^user_id and l.review_id == ^review_id)
  end

  def liked?(nil, %Review{}), do: false

  @doc """
  Identifiants des reviews likees parmi une liste.

  Une requete pour toute une page plutot qu'une par review.
  """
  def liked_review_ids(%Scope{user: %User{id: user_id}}, reviews) when is_list(reviews) do
    ids = Enum.map(reviews, & &1.id)

    from(l in ReviewLike,
      where: l.user_id == ^user_id and l.review_id in ^ids,
      select: l.review_id
    )
    |> Repo.all()
    |> MapSet.new()
  end

  def liked_review_ids(nil, _reviews), do: MapSet.new()

  ## Commentaires

  @doc """
  Commente une review.

  Un commentaire ne peut repondre qu'a un commentaire de la meme review : sans
  cette verification, un identifiant forge rattacherait une reponse a un fil
  etranger.
  """
  def comment(%Scope{user: %User{id: user_id}} = scope, %Review{} = review, attrs) do
    if visible?(scope, review) do
      insert_comment(user_id, review, normalize(attrs))
    else
      {:error, :unauthorized}
    end
  end

  def comment(%Scope{}, %Review{}, _attrs), do: {:error, :unauthorized}

  defp insert_comment(user_id, review, attrs) do
    attrs = Map.merge(attrs, %{"user_id" => user_id, "review_id" => review.id})

    case valid_parent?(review.id, attrs["parent_id"]) do
      false ->
        {:error, :invalid_parent}

      true ->
        Multi.new()
        |> Multi.insert(:comment, ReviewComment.changeset(%ReviewComment{}, attrs))
        |> Multi.run(:count, fn repo, _changes -> refresh_comment_count(repo, review.id) end)
        |> Repo.transaction()
        |> case do
          {:ok, %{comment: comment}} ->
            notify_comment(comment, review)
            {:ok, Repo.preload(comment, :user)}

          {:error, _step, changeset, _changes} ->
            {:error, changeset}
        end
    end
  end

  # Une reponse notifie l'auteur du commentaire parent ; un commentaire racine
  # notifie l'auteur de la review.
  defp notify_comment(%ReviewComment{parent_id: nil} = comment, review) do
    Social.notify(review.user_id, comment.user_id, :review_commented, %{
      review_id: review.id,
      comment_id: comment.id
    })
  end

  defp notify_comment(%ReviewComment{} = comment, review) do
    parent_author =
      Repo.one(from c in ReviewComment, where: c.id == ^comment.parent_id, select: c.user_id)

    Social.notify(parent_author, comment.user_id, :comment_replied, %{
      review_id: review.id,
      comment_id: comment.id
    })
  end

  defp valid_parent?(_review_id, nil), do: true
  defp valid_parent?(_review_id, ""), do: true

  defp valid_parent?(review_id, parent_id) do
    Repo.exists?(
      from c in ReviewComment,
        where: c.id == ^parent_id and c.review_id == ^review_id and is_nil(c.parent_id)
    )
  end

  @doc """
  Supprime un commentaire. Son auteur, ou l'auteur de la review.
  """
  def delete_comment(%Scope{user: %User{id: user_id}}, %ReviewComment{user_id: user_id} = comment) do
    do_delete_comment(comment)
  end

  def delete_comment(%Scope{} = scope, %ReviewComment{} = comment) do
    review = Repo.get(Review, comment.review_id)

    if review && scope.user.id == review.user_id do
      do_delete_comment(comment)
    else
      {:error, :unauthorized}
    end
  end

  defp do_delete_comment(comment) do
    case Repo.delete(comment) do
      {:ok, deleted} ->
        refresh_comment_count(Repo, comment.review_id)
        {:ok, deleted}

      error ->
        error
    end
  end

  @doc """
  Commentaires d'une review, racines d'abord et reponses imbriquees.
  """
  def list_comments(%Review{id: review_id}) do
    Repo.all(
      from c in ReviewComment,
        where: c.review_id == ^review_id and is_nil(c.parent_id),
        order_by: [asc: c.inserted_at],
        preload: [:user, replies: ^replies_query()]
    )
  end

  defp replies_query do
    from c in ReviewComment, order_by: [asc: c.inserted_at], preload: [:user]
  end

  @doc """
  Recupere un commentaire par identifiant.
  """
  def get_comment(id) when is_binary(id) do
    case Integer.parse(id) do
      {parsed, ""} -> Repo.get(ReviewComment, parsed)
      _other -> nil
    end
  end

  def get_comment(id) when is_integer(id), do: Repo.get(ReviewComment, id)

  defp refresh_comment_count(repo, review_id) do
    count = repo.aggregate(from(c in ReviewComment, where: c.review_id == ^review_id), :count)

    repo.update_all(from(r in Review, where: r.id == ^review_id), set: [comments_count: count])

    {:ok, count}
  end

  # Les formulaires envoient des cles binaires, le code appelant des atomes.
  defp normalize(attrs) do
    Map.new(attrs, fn {key, value} -> {to_string(key), value} end)
  end
end
