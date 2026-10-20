defmodule Smovie.Repo.Migrations.CreateActivities do
  use Ecto.Migration

  def up do
    execute """
    CREATE TYPE activity_kind AS ENUM
      ('rated','watched','reviewed','liked_work','followed')
    """

    # Fan-out a la lecture : une ligne par action, lue en filtrant sur le
    # graphe d'abonnements. Dupliquer chaque action chez tous les abonnes
    # ferait exploser la table au premier compte un peu suivi, pour un service
    # qui n'a pas ce probleme.
    create table(:activities) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :kind, :activity_kind, null: false
      add :work_id, references(:works, on_delete: :delete_all)
      add :review_id, references(:reviews, on_delete: :delete_all)
      add :target_user_id, references(:users, on_delete: :delete_all)
      add :rating_value, :smallint

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:activities, [:user_id, :inserted_at])
    create index(:activities, [:inserted_at])
  end

  def down do
    drop table(:activities)
    execute "DROP TYPE activity_kind"
  end
end
