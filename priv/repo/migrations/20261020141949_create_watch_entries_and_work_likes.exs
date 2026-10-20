defmodule Smovie.Repo.Migrations.CreateWatchEntriesAndWorkLikes do
  use Ecto.Migration

  def change do
    # Une entree par visionnage, et non une ligne par (membre, oeuvre) : un
    # re-visionnage doit s'ajouter a l'historique, pas ecraser le precedent.
    create table(:watch_entries) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :work_id, references(:works, on_delete: :delete_all), null: false
      add :watched_on, :date, null: false
      add :rewatch, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:watch_entries, [:user_id, :work_id, :watched_on])
    create index(:watch_entries, [:user_id, :watched_on])
    create index(:watch_entries, [:work_id])

    create table(:work_likes) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :work_id, references(:works, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:work_likes, [:user_id, :work_id])
    create index(:work_likes, [:work_id])
  end
end
