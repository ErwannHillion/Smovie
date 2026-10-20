defmodule Smovie.Social do
  @moduledoc """
  Le graphe social : abonnements, fil d'activite, notifications.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Smovie.Accounts.Scope
  alias Smovie.Accounts.User
  alias Smovie.Repo
  alias Smovie.Social.Follow

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
      {:ok, %{follow: follow}} -> {:ok, follow}
      {:error, _step, changeset, _changes} -> {:error, changeset}
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
