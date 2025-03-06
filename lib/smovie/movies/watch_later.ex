defmodule Smovie.Movies.WatchLater do
  use Ecto.Schema
  import Ecto.Changeset

  schema "watchelater" do
    field :id_movie, :integer
    field :movie_description, :string
    field :movie_title, :string

    belongs_to :user, Smovie.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(watch_later, attrs) do
    watch_later
    |> cast(attrs, [:id_movie, :movie_description, :movie_title])
    |> validate_required([:id_movie, :movie_description, :movie_title])
  end
end
