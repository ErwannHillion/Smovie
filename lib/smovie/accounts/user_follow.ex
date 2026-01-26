defmodule Smovie.Accounts.UserFollow do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_follows" do
    belongs_to :follower, Smovie.Accounts.User
    belongs_to :followed, Smovie.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user_follow, attrs) do
    user_follow
    |> cast(attrs, [:follower_id, :followed_id])
    |> validate_required([:follower_id, :followed_id])
    |> validate_not_self_follow()
    |> unique_constraint([:follower_id, :followed_id])
  end

  defp validate_not_self_follow(changeset) do
    follower_id = get_field(changeset, :follower_id)
    followed_id = get_field(changeset, :followed_id)

    if follower_id && followed_id && follower_id == followed_id do
      add_error(changeset, :followed_id, "cannot follow yourself")
    else
      changeset
    end
  end
end
