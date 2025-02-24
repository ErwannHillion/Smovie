defmodule Smovie.Movies.WatchedList do
  use Ecto.Schema
  import Ecto.Changeset

  schema "watched_lists" do
    field :urating, :float
    field :udescription, :string
    field :uwatcheddate, :date
    field :id_movie, :integer

    belongs_to :user, Smovie.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(watched_list, attrs) do
    watched_list
    |> cast(attrs, [:urating, :udescription, :uwatcheddate, :user_id, :id_movie])
    |> validate_required([:urating, :udescription, :uwatcheddate, :user_id, :id_movie])
  end
end
