defmodule Smovie.Repo.Migrations.CreateUserMovies do
  use Ecto.Migration

  def change do
    create table(:user_movies) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :movie_id, references(:movies, on_delete: :delete_all), null: false
      add :status, :string, null: false # "watched", "watchlist"
      add :rating, :float
      add :review, :text
      add :watched_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:user_movies, [:user_id])
    create index(:user_movies, [:movie_id])
    create unique_index(:user_movies, [:user_id, :movie_id])
  end
end
