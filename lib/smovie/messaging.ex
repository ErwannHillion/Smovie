defmodule Smovie.Messaging do
  @moduledoc """
  Conversations privees et de groupe.

  Toute ecriture prend le `Scope` en premier argument. Les refus portent une
  raison distincte — `:not_a_member`, `:left_conversation`, `:not_allowed` —
  parce que l'interface doit pouvoir expliquer ce qui bloque, et qu'un
  `:unauthorized` unique ne le permettrait pas.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Smovie.Accounts.Scope
  alias Smovie.Accounts.User
  alias Smovie.Messaging.Conversation
  alias Smovie.Messaging.ConversationMember
  alias Smovie.Messaging.Message
  alias Smovie.Repo
  alias Smovie.Social

  @page_size 30

  ## Conversations

  @doc """
  Ouvre la conversation privee entre deux membres, ou la cree.

  L'insertion `on_conflict: :nothing` sur `direct_key` rend le doublon
  impossible meme si deux clics partent en meme temps.
  """
  def find_or_create_direct(%Scope{user: %User{id: me}}, %User{id: other})
      when me != other do
    key = Conversation.direct_key(me, other)

    Multi.new()
    |> Multi.insert(
      :conversation,
      Conversation.direct_changeset(%Conversation{}, %{direct_key: key, created_by_id: me}),
      on_conflict: :nothing,
      conflict_target: :direct_key
    )
    |> Multi.run(:resolved, fn repo, %{conversation: inserted} ->
      {:ok, inserted.id || repo.get_by!(Conversation, direct_key: key)}
    end)
    |> Multi.run(:members, fn repo, %{resolved: resolved} ->
      conversation = resolve(repo, resolved, key)
      add_members(repo, conversation, [{me, :member}, {other, :member}])
      {:ok, conversation}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{members: conversation}} -> {:ok, conversation}
      {:error, _step, reason, _changes} -> {:error, reason}
    end
  end

  def find_or_create_direct(%Scope{user: %User{id: id}}, %User{id: id}),
    do: {:error, :cannot_message_self}

  def find_or_create_direct(%Scope{}, %User{}), do: {:error, :unauthorized}

  defp resolve(_repo, %Conversation{} = conversation, _key), do: conversation
  defp resolve(repo, _id, key), do: repo.get_by!(Conversation, direct_key: key)

  defp add_members(repo, conversation, members) do
    Enum.each(members, fn {user_id, role} ->
      %ConversationMember{}
      |> ConversationMember.changeset(%{
        conversation_id: conversation.id,
        user_id: user_id,
        role: role
      })
      |> repo.insert(on_conflict: :nothing, conflict_target: [:conversation_id, :user_id])
    end)
  end

  @doc """
  Cree une conversation de groupe.
  """
  def create_group(%Scope{user: %User{id: owner_id}}, title, member_ids) do
    members = member_ids |> Enum.uniq() |> Enum.reject(&(&1 == owner_id))

    Multi.new()
    |> Multi.insert(
      :conversation,
      Conversation.group_changeset(%Conversation{}, %{title: title, created_by_id: owner_id})
    )
    |> Multi.run(:members, fn repo, %{conversation: conversation} ->
      add_members(repo, conversation, [{owner_id, :owner}] ++ Enum.map(members, &{&1, :member}))
      {:ok, conversation}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{conversation: conversation}} -> {:ok, conversation}
      {:error, _step, changeset, _changes} -> {:error, changeset}
    end
  end

  def create_group(%Scope{}, _title, _member_ids), do: {:error, :unauthorized}

  @doc """
  Conversations d'un membre, la plus recente en tete.
  """
  def list_conversations(%Scope{user: %User{id: user_id}}) do
    Repo.all(
      from c in Conversation,
        join: m in ConversationMember,
        on: m.conversation_id == c.id,
        where: m.user_id == ^user_id and is_nil(m.left_at),
        order_by: [desc_nulls_last: c.last_message_at, desc: c.id],
        preload: [members: :user]
    )
  end

  def list_conversations(nil), do: []

  @doc """
  Recupere une conversation si le membre y a sa place.
  """
  def get_conversation(%Scope{} = scope, id) do
    with {:ok, parsed} <- cast_id(id),
         %Conversation{} = conversation <- load_conversation(parsed),
         :ok <- authorize_member(scope, conversation) do
      {:ok, conversation}
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def get_conversation(nil, _id), do: {:error, :unauthorized}

  defp cast_id(id) when is_integer(id), do: {:ok, id}

  defp cast_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {parsed, ""} -> {:ok, parsed}
      _other -> {:error, :not_found}
    end
  end

  defp cast_id(_id), do: {:error, :not_found}

  defp load_conversation(id) do
    Repo.one(from c in Conversation, where: c.id == ^id, preload: [members: :user])
  end

  @doc """
  Titre affiche d'une conversation.

  Une conversation privee n'a pas de titre : elle porte le nom de l'autre
  personne, ce qui change selon qui regarde.
  """
  def title(%Conversation{kind: :group, title: title}, _scope), do: title

  def title(%Conversation{kind: :direct} = conversation, %Scope{user: %User{id: me}}) do
    case Enum.find(conversation.members, &(&1.user_id != me)) do
      nil -> ""
      member -> member.user.display_name
    end
  end

  def title(%Conversation{}, _scope), do: ""

  ## Autorisations

  @doc """
  Verifie qu'un membre peut ecrire dans une conversation.

  Trois raisons d'echec distinctes : l'interface doit pouvoir dire « vous
  n'etes pas membre » plutot que « acces refuse ».
  """
  def authorize_member(%Scope{user: %User{id: user_id}}, %Conversation{id: id}) do
    case Repo.get_by(ConversationMember, conversation_id: id, user_id: user_id) do
      %ConversationMember{left_at: nil} -> :ok
      %ConversationMember{} -> {:error, :left_conversation}
      nil -> {:error, :not_a_member}
    end
  end

  def authorize_member(nil, %Conversation{}), do: {:error, :unauthorized}

  @doc """
  Vrai si le membre peut administrer la conversation.
  """
  def admin?(%Scope{user: %User{id: user_id}}, %Conversation{id: id}) do
    Repo.exists?(
      from m in ConversationMember,
        where: m.conversation_id == ^id and m.user_id == ^user_id,
        where: m.role in [:owner, :admin] and is_nil(m.left_at)
    )
  end

  def admin?(nil, %Conversation{}), do: false

  ## Messages

  @doc """
  Envoie un message.

  Le partage d'une review verifie qu'elle est visible **par tous les membres**
  de la conversation : partager une review reservee aux abonnes dans un groupe
  ou quelqu'un ne suit pas l'auteur ferait fuiter son contenu.
  """
  def send_message(
        %Scope{user: %User{id: sender_id}} = scope,
        %Conversation{} = conversation,
        attrs
      ) do
    with :ok <- authorize_member(scope, conversation),
         :ok <- authorize_share(conversation, attrs) do
      insert_message(sender_id, conversation, attrs)
    end
  end

  def send_message(nil, %Conversation{}, _attrs), do: {:error, :unauthorized}

  defp insert_message(sender_id, conversation, attrs) do
    attrs =
      Map.merge(normalize(attrs), %{
        "conversation_id" => conversation.id,
        "sender_id" => sender_id
      })

    Multi.new()
    |> Multi.insert(:message, Message.changeset(%Message{}, attrs))
    |> Multi.update_all(
      :conversation,
      from(c in Conversation, where: c.id == ^conversation.id),
      set: [last_message_at: DateTime.utc_now(:second)]
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{message: message}} ->
        message = Repo.preload(message, [:sender, :shared_work, shared_review: [:user, :work]])
        mark_read(sender_id, conversation.id, message.id)
        broadcast(conversation, message)
        notify_members(conversation, sender_id)
        {:ok, message}

      {:error, _step, changeset, _changes} ->
        {:error, changeset}
    end
  end

  defp authorize_share(conversation, attrs) do
    case normalize(attrs) do
      %{"shared_review_id" => review_id} when not is_nil(review_id) ->
        check_review_visibility(conversation, review_id)

      _other ->
        :ok
    end
  end

  defp check_review_visibility(conversation, review_id) do
    review = Repo.get(Smovie.Reviews.Review, review_id)

    cond do
      is_nil(review) -> {:error, :review_not_found}
      review.visibility == :public -> :ok
      visible_to_all?(conversation, review) -> :ok
      true -> {:error, :review_not_visible_to_all}
    end
  end

  defp visible_to_all?(conversation, review) do
    Enum.all?(active_members(conversation), fn member ->
      Smovie.Reviews.visible?(%Scope{user: member.user}, review)
    end)
  end

  @doc """
  Messages d'une conversation, du plus ancien au plus recent.

  Pagination par curseur sur l'identifiant, jamais par OFFSET : un fil ancien
  coute alors le meme prix qu'un fil recent.
  """
  def list_messages(%Conversation{id: id}, opts \\ []) do
    limit = Keyword.get(opts, :limit, @page_size)
    before_id = Keyword.get(opts, :before_id)

    from(m in Message,
      where: m.conversation_id == ^id,
      order_by: [desc: m.id],
      limit: ^limit,
      preload: [:sender, :shared_work, shared_review: [:user, :work]]
    )
    |> before_cursor(before_id)
    |> Repo.all()
    |> Enum.reverse()
  end

  defp before_cursor(query, nil), do: query
  defp before_cursor(query, before_id), do: from(m in query, where: m.id < ^before_id)

  @doc """
  Supprime un message : son auteur, ou un administrateur du groupe.

  Le message n'est pas efface mais marque : une bulle « message supprime »
  garde le fil lisible, la ou un trou laisserait croire a un bug.
  """
  def delete_message(%Scope{user: %User{id: user_id}} = scope, %Message{} = message) do
    conversation = load_conversation(message.conversation_id)

    if message.sender_id == user_id or admin?(scope, conversation) do
      message
      |> Ecto.Changeset.change(deleted_at: DateTime.utc_now(:second), body: nil)
      |> Repo.update()
    else
      {:error, :not_allowed}
    end
  end

  ## Non-lus

  @doc """
  Marque la conversation comme lue jusqu'au dernier message.
  """
  def mark_read(%Scope{user: %User{id: user_id}}, %Conversation{id: id}) do
    last_id = Repo.one(from m in Message, where: m.conversation_id == ^id, select: max(m.id))

    mark_read(user_id, id, last_id)
  end

  defp mark_read(_user_id, _conversation_id, nil), do: :ok

  defp mark_read(user_id, conversation_id, message_id) do
    Repo.update_all(
      from(m in ConversationMember,
        where: m.conversation_id == ^conversation_id and m.user_id == ^user_id
      ),
      set: [last_read_message_id: message_id]
    )

    Phoenix.PubSub.broadcast(Smovie.PubSub, Social.inbox_topic(user_id), :unread_changed)

    :ok
  end

  @doc """
  Nombre de messages non lus, toutes conversations confondues.

  Les messages qu'on a soi-meme envoyes ne comptent pas : ils seraient
  toujours non lus par definition.
  """
  def unread_count(%Scope{user: %User{id: user_id}}) do
    from(m in Message,
      join: cm in ConversationMember,
      on: cm.conversation_id == m.conversation_id and cm.user_id == ^user_id,
      where: is_nil(cm.left_at),
      where: m.id > coalesce(cm.last_read_message_id, 0),
      where: m.sender_id != ^user_id,
      where: is_nil(m.deleted_at),
      select: count(m.id)
    )
    |> Repo.one()
  end

  def unread_count(nil), do: 0

  @doc """
  Non-lus par conversation, pour la liste.
  """
  def unread_by_conversation(%Scope{user: %User{id: user_id}}) do
    from(m in Message,
      join: cm in ConversationMember,
      on: cm.conversation_id == m.conversation_id and cm.user_id == ^user_id,
      where: is_nil(cm.left_at),
      where: m.id > coalesce(cm.last_read_message_id, 0),
      where: m.sender_id != ^user_id,
      where: is_nil(m.deleted_at),
      group_by: m.conversation_id,
      select: {m.conversation_id, count(m.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  def unread_by_conversation(nil), do: %{}

  ## Diffusion

  @doc """
  Sujet PubSub d'une conversation.
  """
  def topic(%Conversation{id: id}), do: "conversation:#{id}"

  defp broadcast(conversation, message) do
    Phoenix.PubSub.broadcast(Smovie.PubSub, topic(conversation), {:new_message, message})
  end

  defp notify_members(conversation, sender_id) do
    conversation
    |> active_members()
    |> Enum.reject(&(&1.user_id == sender_id))
    |> Enum.each(fn member ->
      Social.notify(member.user_id, sender_id, :new_message)
    end)
  end

  @doc """
  Membres actifs d'une conversation.
  """
  def active_members(%Conversation{members: members}) when is_list(members) do
    Enum.filter(members, &is_nil(&1.left_at))
  end

  def active_members(%Conversation{id: id}) do
    Repo.all(
      from m in ConversationMember,
        where: m.conversation_id == ^id and is_nil(m.left_at),
        preload: [:user]
    )
  end

  defp normalize(attrs), do: Map.new(attrs, fn {key, value} -> {to_string(key), value} end)
end
