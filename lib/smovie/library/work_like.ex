defmodule Smovie.Library.WorkLike do
  @moduledoc """
  Coup de coeur d'un membre pour une oeuvre.

  Distinct de la note : on peut reconnaitre qu'un film est excellent sans
  l'aimer, et aimer un film qu'on sait mauvais.
  """
  use Ecto.Schema

  import Ecto.Changeset

  schema "work_likes" do
    belongs_to :user, Smovie.Accounts.User
    belongs_to :work, Smovie.Catalog.Work

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(like, attrs) do
    like
    |> cast(attrs, [:user_id, :work_id])
    |> validate_required([:user_id, :work_id])
    |> unique_constraint([:user_id, :work_id])
    |> foreign_key_constraint(:work_id)
  end
end
