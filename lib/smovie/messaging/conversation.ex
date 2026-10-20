defmodule Smovie.Messaging.Conversation do
  @moduledoc """
  Une conversation, privee ou de groupe.

  `direct_key` porte `"<min_id>:<max_id>"` et un index unique. Sans elle, deux
  clics simultanes sur « Envoyer un message » creeraient deux conversations
  entre les memes personnes, et les messages se repartiraient entre les deux.
  """
  use Ecto.Schema

  import Ecto.Changeset

  schema "conversations" do
    field :kind, Ecto.Enum, values: [:direct, :group]
    field :title, :string
    field :direct_key, :string
    field :last_message_at, :utc_datetime

    belongs_to :created_by, Smovie.Accounts.User
    has_many :members, Smovie.Messaging.ConversationMember
    has_many :messages, Smovie.Messaging.Message

    timestamps(type: :utc_datetime)
  end

  def direct_changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:direct_key, :created_by_id])
    |> put_change(:kind, :direct)
    |> validate_required([:direct_key])
    |> unique_constraint(:direct_key)
  end

  def group_changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:title, :created_by_id])
    |> put_change(:kind, :group)
    |> validate_required([:title, :created_by_id])
    |> validate_length(:title, min: 1, max: 120)
  end

  @doc """
  Cle d'une conversation privee entre deux membres.

  L'ordre est normalise : sans cela, (3, 7) et (7, 3) donneraient deux cles
  differentes et l'unicite ne servirait a rien.
  """
  def direct_key(a, b) when is_integer(a) and is_integer(b) do
    "#{min(a, b)}:#{max(a, b)}"
  end
end
