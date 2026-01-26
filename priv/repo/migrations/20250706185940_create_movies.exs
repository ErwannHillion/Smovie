defmodule Smovie.Repo.Migrations.CreateMovies do
  use Ecto.Migration

  def change do
    create table(:movies) do
      add :tmdb_id, :integer, null: false
      add :title, :string, null: false
      add :original_title, :string
      add :overview, :text
      add :release_date, :date
      add :poster_path, :string
      add :backdrop_path, :string
      add :vote_average, :float
      add :vote_count, :integer
      add :runtime, :integer
      add :genres, {:array, :string}
      add :director, :string
      add :cast, {:array, :string}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:movies, [:tmdb_id])
  end
end
