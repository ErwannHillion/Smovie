defmodule Smovie.Reviews.CommentLike do
  @moduledoc "Like d'un membre sur un commentaire."
  use Ecto.Schema

  import Ecto.Changeset

  schema "comment_likes" do
    belongs_to :user, Smovie.Accounts.User
    belongs_to :comment, Smovie.Reviews.ReviewComment

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(like, attrs) do
    like
    |> cast(attrs, [:user_id, :comment_id])
    |> validate_required([:user_id, :comment_id])
    |> unique_constraint([:user_id, :comment_id])
    |> foreign_key_constraint(:comment_id)
  end
end
