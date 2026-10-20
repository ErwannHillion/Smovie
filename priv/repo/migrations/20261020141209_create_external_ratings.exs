defmodule Smovie.Repo.Migrations.CreateExternalRatings do
  use Ecto.Migration

  def up do
    execute "CREATE TYPE rating_source AS ENUM ('imdb','metacritic','rotten_tomatoes','tmdb','allocine')"

    create table(:external_ratings) do
      add :work_id, references(:works, on_delete: :delete_all), null: false
      add :source, :rating_source, null: false
      add :score, :decimal, precision: 5, scale: 2, null: false
      # L'echelle est stockee avec la note : 7.8 sur 10 et 78 sur 100 sont la
      # meme appreciation, et les confondre a l'affichage serait grossier.
      add :scale, :smallint, null: false
      add :votes_count, :integer
      add :url, :string
      add :fetched_at, :utc_datetime, null: false
    end

    create unique_index(:external_ratings, [:work_id, :source])
    create constraint(:external_ratings, :external_ratings_scale, check: "scale IN (10, 100)")
    create constraint(:external_ratings, :external_ratings_score, check: "score >= 0")
  end

  def down do
    drop table(:external_ratings)
    execute "DROP TYPE rating_source"
  end
end
