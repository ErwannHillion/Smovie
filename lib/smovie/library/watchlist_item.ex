defmodule Smovie.Library.WatchlistItem do
  @moduledoc """
  Une oeuvre qu'un membre a l'intention de voir.

  Seuls les films et les series entrent dans une watchlist : on ne met pas un
  episode « a voir », on reprend une serie la ou on l'a laissee.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias Smovie.Catalog.WorkKind

  schema "watchlist_items" do
    field :note, :string

    belongs_to :user, Smovie.Accounts.User
    belongs_to :work, Smovie.Catalog.Work

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:user_id, :work_id, :note])
    |> validate_required([:user_id, :work_id])
    |> validate_length(:note, max: 280)
    |> unique_constraint([:user_id, :work_id])
    |> foreign_key_constraint(:work_id)
  end

  @doc "Natures qu'on peut mettre a voir."
  def allowed_kinds, do: WorkKind.watchlistable()
end
