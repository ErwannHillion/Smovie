defmodule Smovie.Repo.Migrations.CreateGenresPeopleAndCredits do
  use Ecto.Migration

  def up do
    execute "CREATE TYPE credit_kind AS ENUM ('cast','crew')"

    create table(:genres) do
      add :tmdb_id, :integer, null: false
      add :name, :string, size: 60, null: false
      add :slug, :string, size: 60, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:genres, [:tmdb_id])
    create unique_index(:genres, [:slug])

    # Table de jonction plutot qu'un tableau `genres text[]` sur works : on
    # filtre et on compte par genre, ce qu'un tableau ne sait pas indexer
    # efficacement.
    create table(:work_genres, primary_key: false) do
      add :work_id, references(:works, on_delete: :delete_all), null: false
      add :genre_id, references(:genres, on_delete: :delete_all), null: false
    end

    create unique_index(:work_genres, [:work_id, :genre_id])
    create index(:work_genres, [:genre_id])

    create table(:people) do
      add :tmdb_id, :integer, null: false
      add :name, :string, size: 200, null: false
      add :slug, :string, size: 220, null: false
      add :profile_path, :string
      add :known_for_department, :string, size: 60
      add :birthday, :date
      add :deathday, :date
      add :biography, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:people, [:tmdb_id])
    create unique_index(:people, [:slug])
    execute "CREATE INDEX people_name_trgm_index ON people USING gin (name gin_trgm_ops)"

    # Jonction plutot que `director varchar` + `cast text[]` : on veut chercher
    # par realisateur et ouvrir une page personne, ce qu'une chaine interdit.
    create table(:credits) do
      add :work_id, references(:works, on_delete: :delete_all), null: false
      add :person_id, references(:people, on_delete: :delete_all), null: false
      add :kind, :credit_kind, null: false
      add :department, :string, size: 60
      add :job, :string, size: 120
      add :character, :string, size: 200
      add :display_order, :integer
    end

    # Une meme personne peut apparaitre deux fois sur une oeuvre : realisatrice
    # et scenariste, ou interprete de deux roles. La cle inclut donc le poste.
    create unique_index(
             :credits,
             [:work_id, :person_id, :kind, "coalesce(job, '')", "coalesce(character, '')"],
             name: :credits_unique
           )

    create index(:credits, [:work_id, :kind, :display_order])
    create index(:credits, [:person_id])
  end

  def down do
    drop table(:credits)
    drop table(:people)
    drop table(:work_genres)
    drop table(:genres)
    execute "DROP TYPE credit_kind"
  end
end
