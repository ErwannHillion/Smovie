defmodule Smovie.Repo.Migrations.CreateRatings do
  use Ecto.Migration

  def up do
    create table(:ratings) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :work_id, references(:works, on_delete: :delete_all), null: false
      # Nombre de demi-etoiles, de 1 a 10. Entier et non flottant : pas
      # d'arrondi parasite, et une agregation exacte.
      add :value, :smallint, null: false
      add :rated_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:ratings, [:user_id, :work_id])
    create index(:ratings, [:work_id, :rated_at])
    create index(:ratings, [:user_id, :rated_at])
    create constraint(:ratings, :ratings_value_range, check: "value BETWEEN 1 AND 10")

    # Moyenne de la plateforme, dans une table d'une ligne. La relire a chaque
    # note serait un scan complet de `ratings` ; un job horaire la rafraichit.
    create table(:rating_stats, primary_key: false) do
      add :id, :boolean, primary_key: true, default: true
      add :global_average, :decimal, precision: 4, scale: 2, null: false
      add :ratings_count, :integer, null: false, default: 0
      add :computed_at, :utc_datetime, null: false
    end

    create constraint(:rating_stats, :rating_stats_singleton, check: "id IS TRUE")

    execute """
    INSERT INTO rating_stats (id, global_average, ratings_count, computed_at)
    VALUES (true, 6.80, 0, now())
    """
  end

  def down do
    drop table(:rating_stats)
    drop table(:ratings)
  end
end
