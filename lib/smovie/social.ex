defmodule Smovie.Social do
  @moduledoc """
  Le graphe social : abonnements, fil d'activite, notifications.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Smovie.Accounts.Scope
  alias Smovie.Accounts.User
  alias Smovie.Repo
  alias Smovie.Social.Activity
  alias Smovie.Social.Follow
  alias Smovie.Social.Notification

  @doc """
  Suit un membre.

  Les compteurs des deux comptes sont mis a jour dans la meme transaction que
  l'abonnement : un compteur recalcule apres coup se desynchronise au premier
  plantage, et plus rien ne le remet d'aplomb.
  """
  def follow(%Scope{user: %User{id: follower_id}}, %User{id: followed_id})
      when follower_id != followed_id do
    Multi.new()
    |> Multi.insert(
      :follow,
      Follow.changeset(%Follow{}, %{follower_id: follower_id, followed_id: followed_id}),
      on_conflict: :nothing,
      conflict_target: [:follower_id, :followed_id]
    )
    |> Multi.run(:counters, fn _repo, _changes ->
      refresh_counters(follower_id, followed_id)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{follow: follow}} ->
        record(%Scope{user: %User{id: follower_id}}, :followed, %{target_user_id: followed_id})
        notify(followed_id, follower_id, :new_follower)
        {:ok, follow}

      {:error, _step, changeset, _changes} ->
        {:error, changeset}
    end
  end

  def follow(%Scope{user: %User{id: id}}, %User{id: id}), do: {:error, :cannot_follow_self}
  def follow(%Scope{}, %User{}), do: {:error, :unauthorized}

  @doc """
  Ne suit plus un membre.
  """
  def unfollow(%Scope{user: %User{id: follower_id}}, %User{id: followed_id}) do
    query =
      from f in Follow,
        where: f.follower_id == ^follower_id and f.followed_id == ^followed_id

    case Repo.delete_all(query) do
      {0, _} ->
        {:error, :not_following}

      {_count, _} ->
        refresh_counters(follower_id, followed_id)
        :ok
    end
  end

  def unfollow(%Scope{}, %User{}), do: {:error, :unauthorized}

  @doc """
  Bascule l'abonnement.
  """
  def toggle_follow(%Scope{} = scope, %User{} = user) do
    if following?(scope, user) do
      unfollow(scope, user)
      {:ok, :unfollowed}
    else
      case follow(scope, user) do
        {:ok, _follow} -> {:ok, :followed}
        error -> error
      end
    end
  end

  @doc """
  Vrai si le membre du scope suit `user`.
  """
  def following?(%Scope{user: %User{id: follower_id}}, %User{id: followed_id}) do
    Repo.exists?(
      from f in Follow,
        where: f.follower_id == ^follower_id and f.followed_id == ^followed_id
    )
  end

  def following?(nil, %User{}), do: false

  @doc """
  Identifiants des membres suivis.

  Utilise par le fil d'activite et les blocs « chez vos amis » : une liste
  d'identifiants se passe en parametre d'une requete, la ou une liste de
  structs obligerait a la reparcourir.
  """
  def following_ids(%Scope{user: %User{id: follower_id}}) do
    Repo.all(from f in Follow, where: f.follower_id == ^follower_id, select: f.followed_id)
  end

  def following_ids(nil), do: []

  @doc """
  Membres suivis par `user`.
  """
  def list_following(%User{id: follower_id}, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    Repo.all(
      from u in User,
        join: f in Follow,
        on: f.followed_id == u.id,
        where: f.follower_id == ^follower_id,
        order_by: [desc: f.inserted_at],
        limit: ^limit
    )
  end

  @doc """
  Membres qui suivent `user`.
  """
  def list_followers(%User{id: followed_id}, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    Repo.all(
      from u in User,
        join: f in Follow,
        on: f.follower_id == u.id,
        where: f.followed_id == ^followed_id,
        order_by: [desc: f.inserted_at],
        limit: ^limit
    )
  end

  @doc """
  Suggestions de membres a suivre.

  Les plus actifs d'abord, et jamais soi-meme ni quelqu'un qu'on suit deja :
  proposer un compte deja suivi est le genre de detail qui fait douter du
  reste.
  """
  def suggestions(%Scope{user: %User{id: user_id}} = scope, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    exclude = [user_id | following_ids(scope)]

    Repo.all(
      from u in User,
        where: u.id not in ^exclude,
        order_by: [desc: u.followers_count, desc: u.id],
        limit: ^limit
    )
  end

  ## Fil d'activite

  @doc """
  Enregistre une activite.

  Silencieuse en cas d'echec : une activite est un effet de bord d'une action
  reussie, et la perdre ne doit jamais faire echouer l'action elle-meme. On ne
  va pas refuser une note parce que le fil n'a pas pu l'enregistrer.
  """
  def record(%Scope{user: %User{id: user_id}}, kind, attrs) do
    %Activity{}
    |> Activity.changeset(Map.merge(attrs, %{user_id: user_id, kind: kind}))
    |> Repo.insert()
    |> case do
      {:ok, activity} -> {:ok, activity}
      {:error, _changeset} -> :ignored
    end
  end

  def record(_scope, _kind, _attrs), do: :ignored

  @doc """
  Fil des comptes suivis.

  Les visibilites sont appliquees a la lecture : une oeuvre reste une oeuvre,
  mais une activite dont l'auteur a ferme son profil n'a pas a circuler.
  """
  def list_feed(scope, opts \\ [])

  def list_feed(%Scope{} = scope, opts) do
    limit = Keyword.get(opts, :limit, 30)
    ids = following_ids(scope)

    if ids == [] do
      []
    else
      Repo.all(
        from a in Activity,
          join: u in assoc(a, :user),
          where: a.user_id in ^ids,
          where: u.profile_visibility in [:public, :followers],
          order_by: [desc: a.inserted_at, desc: a.id],
          limit: ^limit,
          preload: [:user, :work, :target_user, review: :work]
      )
    end
  end

  def list_feed(nil, _opts), do: []

  @doc """
  Activite d'un membre, pour son profil.
  """
  def list_user_activity(%User{id: user_id}, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    Repo.all(
      from a in Activity,
        where: a.user_id == ^user_id,
        order_by: [desc: a.inserted_at, desc: a.id],
        limit: ^limit,
        preload: [:user, :work, :target_user, review: :work]
    )
  end

  @doc """
  Purge les activites au-dela de `days` jours.

  Un fil ne se consulte pas au-dela de quelques semaines : conserver
  indefiniment ferait grossir la table sans que personne n'y gagne.
  """
  def purge_activities(days \\ 90) do
    threshold = DateTime.add(DateTime.utc_now(), -days, :day)

    {count, _} = Repo.delete_all(from a in Activity, where: a.inserted_at < ^threshold)

    {:ok, count}
  end

  ## Notifications

  @doc """
  Notifie un membre.

  On ne se notifie jamais soi-meme : liker sa propre review ou se repondre ne
  doit pas allumer le badge. La verification vit ici plutot qu'a chaque point
  d'appel, ou elle finirait par etre oubliee une fois.

  Comme pour les activites, un echec est silencieux : une notification perdue
  ne doit pas faire echouer l'action qui l'a declenchee.
  """
  def notify(recipient_id, actor_id, kind, attrs \\ %{})

  def notify(same_id, same_id, _kind, _attrs), do: :ignored

  def notify(recipient_id, actor_id, kind, attrs) do
    %Notification{}
    |> Notification.changeset(
      Map.merge(attrs, %{user_id: recipient_id, actor_id: actor_id, kind: kind})
    )
    |> Repo.insert()
    |> case do
      {:ok, notification} ->
        broadcast_unread(recipient_id)
        {:ok, notification}

      {:error, _changeset} ->
        :ignored
    end
  end

  @doc """
  Notifications d'un membre, des plus recentes.
  """
  def list_notifications(%Scope{user: %User{id: user_id}}, opts \\ []) do
    limit = Keyword.get(opts, :limit, 40)

    Repo.all(
      from n in Notification,
        where: n.user_id == ^user_id,
        order_by: [desc: n.inserted_at, desc: n.id],
        limit: ^limit,
        preload: [:actor, :work, review: :work]
    )
  end

  @doc """
  Nombre de notifications non lues.
  """
  def unread_count(%Scope{user: %User{id: user_id}}) do
    Repo.aggregate(
      from(n in Notification, where: n.user_id == ^user_id and is_nil(n.read_at)),
      :count
    )
  end

  def unread_count(nil), do: 0

  @doc """
  Marque toutes les notifications comme lues.
  """
  def mark_all_read(%Scope{user: %User{id: user_id}}) do
    {count, _} =
      Repo.update_all(
        from(n in Notification, where: n.user_id == ^user_id and is_nil(n.read_at)),
        set: [read_at: DateTime.utc_now(:second)]
      )

    broadcast_unread(user_id)

    {:ok, count}
  end

  @doc """
  Sujet PubSub de la boite d'un membre.
  """
  def inbox_topic(user_id), do: "user:#{user_id}:inbox"

  defp broadcast_unread(user_id) do
    Phoenix.PubSub.broadcast(Smovie.PubSub, inbox_topic(user_id), :unread_changed)
  end

  defp refresh_counters(follower_id, followed_id) do
    update_count(follower_id, :following_count, :follower_id)
    update_count(followed_id, :followers_count, :followed_id)

    {:ok, :updated}
  end

  defp update_count(user_id, field, column) do
    count =
      Repo.aggregate(from(f in Follow, where: field(f, ^column) == ^user_id), :count)

    Repo.update_all(from(u in User, where: u.id == ^user_id), set: [{field, count}])
  end
end
