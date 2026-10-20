defmodule Smovie.Social.Notification do
  @moduledoc """
  Notification destinee a un membre.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @kinds [
    :new_follower,
    :review_liked,
    :review_commented,
    :comment_replied,
    :new_message,
    :friend_rated_watchlist
  ]

  schema "notifications" do
    field :kind, Ecto.Enum, values: @kinds
    field :read_at, :utc_datetime

    belongs_to :user, Smovie.Accounts.User
    belongs_to :actor, Smovie.Accounts.User
    belongs_to :work, Smovie.Catalog.Work
    belongs_to :review, Smovie.Reviews.Review
    belongs_to :comment, Smovie.Reviews.ReviewComment

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def kinds, do: @kinds

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:user_id, :actor_id, :kind, :work_id, :review_id, :comment_id, :read_at])
    |> validate_required([:user_id, :kind])
    |> foreign_key_constraint(:user_id)
  end
end
