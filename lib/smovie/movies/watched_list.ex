defmodule Smovie.Movies.WatchedList do
  use Ecto.Schema
  import Ecto.Changeset

  schema "watchedlist" do
    field :urating, :float
    field :udescription, :string
    field :uwatcheddate, :date
    field :user, :id
    field :id_movie, :integer

    timestamps(type: :utc_datetime)

    belongs_to :users, Smovie.Accounts.User
  end

  @doc false
  def changeset(watched_list, attrs) do
    watched_list
    |> cast(attrs, [:urating, :udescription, :uwatcheddate])
    |> validate_required([:urating, :udescription, :uwatcheddate])
  end
end
