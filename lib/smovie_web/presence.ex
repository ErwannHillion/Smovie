defmodule SmovieWeb.Presence do
  @moduledoc """
  Presence des membres.

  Deux usages, deux sujets : `presence:online` pour savoir qui est connecte,
  et `presence:conversation:<id>` pour la frappe en cours. Les melanger
  obligerait chaque fil a recevoir les connexions de toute l'application.
  """
  use Phoenix.Presence,
    otp_app: :smovie,
    pubsub_server: Smovie.PubSub

  @online_topic "presence:online"

  def online_topic, do: @online_topic

  def conversation_topic(conversation_id), do: "presence:conversation:#{conversation_id}"

  @doc """
  Annonce qu'un membre est connecte.
  """
  def track_online(pid, %{id: user_id}) do
    track(pid, @online_topic, to_string(user_id), %{at: System.system_time(:second)})
  end

  @doc """
  Suit la presence d'un membre dans une conversation.
  """
  def track_conversation(pid, conversation_id, %{id: user_id, display_name: name}) do
    track(pid, conversation_topic(conversation_id), to_string(user_id), %{
      name: name,
      typing: false
    })
  end

  @doc """
  Signale que le membre est en train d'ecrire, ou qu'il a cesse.
  """
  def set_typing(pid, conversation_id, %{id: user_id}, typing?) do
    update(
      pid,
      conversation_topic(conversation_id),
      to_string(user_id),
      &Map.put(&1, :typing, typing?)
    )
  end

  @doc """
  Noms des membres qui ecrivent, hors soi-meme.
  """
  def typing_names(conversation_id, %{id: me}) do
    # Phoenix.Presence indexe par chaine : comparer a un entier ne matcherait
    # jamais, et l'on se verrait soi-meme ecrire.
    me = to_string(me)

    conversation_id
    |> conversation_topic()
    |> list()
    |> Enum.reject(fn {user_id, _presence} -> user_id == me end)
    |> Enum.filter(fn {_id, %{metas: metas}} -> Enum.any?(metas, & &1.typing) end)
    |> Enum.map(fn {_id, %{metas: [meta | _]}} -> meta.name end)
  end

  @doc """
  Vrai si le membre est connecte quelque part.
  """
  def online?(user_id) do
    @online_topic |> list() |> Map.has_key?(to_string(user_id))
  end
end
