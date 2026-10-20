defmodule Smovie.Social.Follow do
  @moduledoc """
  Abonnement d'un membre a un autre.

  Asymetrique et sans demande a accepter : suivre quelqu'un, c'est choisir de
  voir son activite, pas lui demander la permission. Ce qu'il montre reste
  regi par ses visibilites.
  """
  use Ecto.Schema

  import Ecto.Changeset

  schema "follows" do
    belongs_to :follower, Smovie.Accounts.User
    belongs_to :followed, Smovie.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(follow, attrs) do
    follow
    |> cast(attrs, [:follower_id, :followed_id])
    |> validate_required([:follower_id, :followed_id])
    |> validate_not_self()
    |> unique_constraint([:follower_id, :followed_id])
    |> check_constraint(:followed_id,
      name: :follows_not_self,
      message: "ne peut pas etre soi-meme"
    )
    |> foreign_key_constraint(:followed_id)
  end

  defp validate_not_self(changeset) do
    follower = get_field(changeset, :follower_id)
    followed = get_field(changeset, :followed_id)

    if follower && follower == followed do
      add_error(changeset, :followed_id, "ne peut pas etre soi-meme")
    else
      changeset
    end
  end
end
