defmodule Smovie.Messaging.ConversationMember do
  @moduledoc """
  Participation d'un membre a une conversation.

  `last_read_message_id` est un pointeur, et non une table d'accuses par
  message : le non-lu se compte alors par un COUNT indexe, et le volume reste
  constant quel que soit le nombre de messages.
  """
  use Ecto.Schema

  import Ecto.Changeset

  schema "conversation_members" do
    field :role, Ecto.Enum, values: [:owner, :admin, :member], default: :member
    field :last_read_message_id, :integer
    field :muted_until, :utc_datetime
    field :joined_at, :utc_datetime
    field :left_at, :utc_datetime

    belongs_to :conversation, Smovie.Messaging.Conversation
    belongs_to :user, Smovie.Accounts.User
  end

  def changeset(member, attrs) do
    member
    |> cast(attrs, [
      :conversation_id,
      :user_id,
      :role,
      :last_read_message_id,
      :muted_until,
      :left_at
    ])
    |> validate_required([:conversation_id, :user_id])
    |> put_joined_at()
    |> unique_constraint([:conversation_id, :user_id])
  end

  defp put_joined_at(changeset) do
    case get_field(changeset, :joined_at) do
      nil -> put_change(changeset, :joined_at, DateTime.utc_now(:second))
      _existing -> changeset
    end
  end
end
