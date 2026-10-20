defmodule Smovie.Reviews.ReviewLike do
  @moduledoc "Like d'un membre sur une review."
  use Ecto.Schema

  import Ecto.Changeset

  schema "review_likes" do
    belongs_to :user, Smovie.Accounts.User
    belongs_to :review, Smovie.Reviews.Review

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(like, attrs) do
    like
    |> cast(attrs, [:user_id, :review_id])
    |> validate_required([:user_id, :review_id])
    |> unique_constraint([:user_id, :review_id])
    |> foreign_key_constraint(:review_id)
  end
end
