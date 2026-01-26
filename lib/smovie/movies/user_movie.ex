defmodule Smovie.Movies.UserMovie do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_movies" do
    field :status, :string
    field :rating, :float
    field :review, :string
    field :watched_at, :utc_datetime

    belongs_to :user, Smovie.Accounts.User
    belongs_to :movie, Smovie.Movies.Movie

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user_movie, attrs) do
    user_movie
    |> cast(attrs, [:user_id, :movie_id, :status, :rating, :review, :watched_at])
    |> validate_required([:user_id, :movie_id, :status])
    |> validate_inclusion(:status, ["watched", "watchlist"])
    |> validate_number(:rating, greater_than_or_equal_to: 0, less_than_or_equal_to: 10)
    |> unique_constraint([:user_id, :movie_id])
  end
end
