defmodule Smovie.Repo.Migrations.CreateWorks do
  use Ecto.Migration

  @moduledoc """
  Table unique pour les quatre natures d'oeuvre.

  Film, serie, saison et episode partagent une table, avec un discriminant
  `kind` et une auto-reference `parent_id`. La couche sociale — note, review,
  like, watchlist, partage, activite, notification, tendance — represente
  l'essentiel du code a venir : avec une table par nature il faudrait l'ecrire
  quatre fois, ou reposer sur une cle polymorphe sans integrite
  referentielle. Ici, « noter un episode » est le meme code avec un autre
  work_id.
  """

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"
    execute "CREATE TYPE work_kind AS ENUM ('movie','tv_show','season','episode')"

    create table(:works) do
      add :kind, :work_kind, null: false
      add :parent_id, references(:works, on_delete: :delete_all)

      add :tmdb_id, :integer, null: false
      add :imdb_id, :string, size: 12
      add :slug, :string, size: 160, null: false

      add :title, :string, size: 300, null: false
      add :original_title, :string, size: 300
      add :overview, :text
      add :tagline, :string, size: 300

      add :release_date, :date
      add :runtime, :integer
      add :poster_path, :string
      add :backdrop_path, :string
      add :original_language, :string, size: 8

      add :season_number, :integer
      add :episode_number, :integer
      add :episode_count, :integer
      add :season_count, :integer

      add :status, :string, size: 40
      add :adult, :boolean, null: false, default: false

      add :tmdb_popularity, :decimal, precision: 10, scale: 3
      add :tmdb_vote_average, :decimal, precision: 4, scale: 2
      add :tmdb_vote_count, :integer

      # Moyenne bayesienne, en demi-etoiles (1..10). Maintenue dans la meme
      # transaction que l'insertion d'une note.
      add :smovie_rating_avg, :decimal, precision: 4, scale: 2
      add :smovie_rating_count, :integer, null: false, default: 0
      add :smovie_watch_count, :integer, null: false, default: 0
      add :smovie_review_count, :integer, null: false, default: 0

      add :synced_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # Colonne generee : la recherche plein texte reste juste sans qu'aucun code
    # applicatif n'ait a penser a la mettre a jour.
    execute """
    ALTER TABLE works ADD COLUMN search_vector tsvector
      GENERATED ALWAYS AS (
        to_tsvector('french',
          coalesce(title, '') || ' ' || coalesce(original_title, '')
        )
      ) STORED
    """

    create unique_index(:works, [:kind, :tmdb_id])
    create unique_index(:works, [:slug])
    create index(:works, [:parent_id])
    create index(:works, [:kind, :release_date])
    create index(:works, [:kind, :tmdb_popularity])
    create index(:works, [:imdb_id])
    create index(:works, [:search_vector], using: :gin)

    # Tolerance aux fautes de frappe sur le titre, en complement du plein texte.
    execute "CREATE INDEX works_title_trgm_index ON works USING gin (title gin_trgm_ops)"

    # Une serie n'a qu'une saison 3, une saison qu'un episode 7.
    create unique_index(:works, [:parent_id, :season_number],
             where: "kind = 'season'",
             name: :works_season_unique
           )

    create unique_index(:works, [:parent_id, :episode_number],
             where: "kind = 'episode'",
             name: :works_episode_unique
           )

    # La hierarchie est garantie par la base, pas seulement par le changeset :
    # un episode sans parent serait un orphelin impossible a rattacher.
    create constraint(:works, :works_hierarchy,
             check: """
             (kind IN ('movie','tv_show') AND parent_id IS NULL)
             OR (kind IN ('season','episode') AND parent_id IS NOT NULL)
             """
           )

    create constraint(:works, :works_season_number,
             check: "(kind IN ('season','episode')) = (season_number IS NOT NULL)"
           )

    create constraint(:works, :works_episode_number,
             check: "(kind = 'episode') = (episode_number IS NOT NULL)"
           )

    create constraint(:works, :works_rating_count_positive, check: "smovie_rating_count >= 0")
  end

  def down do
    drop table(:works)
    execute "DROP TYPE work_kind"
  end
end
