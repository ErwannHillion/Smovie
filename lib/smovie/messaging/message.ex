defmodule Smovie.Messaging.Message do
  @moduledoc """
  Un message.

  Un partage ne copie rien : il porte une reference vers l'oeuvre ou la
  review. La carte affichee dans une conversation de la semaine derniere
  montre donc la note d'aujourd'hui, et une oeuvre supprimee degrade la carte
  proprement au lieu de laisser un lien mort.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @max_length 4_000

  schema "messages" do
    field :kind, Ecto.Enum, values: [:text, :work_share, :review_share, :system], default: :text
    field :body, :string
    field :edited_at, :utc_datetime
    field :deleted_at, :utc_datetime

    belongs_to :conversation, Smovie.Messaging.Conversation
    belongs_to :sender, Smovie.Accounts.User
    belongs_to :shared_work, Smovie.Catalog.Work
    belongs_to :shared_review, Smovie.Reviews.Review
    belongs_to :reply_to, __MODULE__

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def max_length, do: @max_length

  def changeset(message, attrs) do
    message
    |> cast(attrs, [
      :conversation_id,
      :sender_id,
      :kind,
      :body,
      :shared_work_id,
      :shared_review_id,
      :reply_to_id
    ])
    |> validate_required([:conversation_id, :sender_id, :kind])
    |> update_change(:body, &trim/1)
    |> validate_body()
    |> validate_length(:body, max: @max_length)
    |> check_constraint(:body, name: :messages_text_body)
    |> check_constraint(:shared_work_id, name: :messages_work_share)
    |> check_constraint(:shared_review_id, name: :messages_review_share)
    |> foreign_key_constraint(:conversation_id)
  end

  defp trim(nil), do: nil
  defp trim(body), do: String.trim(body)

  defp validate_body(changeset) do
    case get_field(changeset, :kind) do
      :text -> validate_required(changeset, [:body])
      _other -> changeset
    end
  end

  @doc """
  Vrai si le message a ete supprime.
  """
  def deleted?(%__MODULE__{deleted_at: nil}), do: false
  def deleted?(%__MODULE__{}), do: true
end
