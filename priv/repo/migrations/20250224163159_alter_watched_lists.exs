defmodule Smovie.Repo.Migrations.AlterWatchedLists do
  use Ecto.Migration

  def change do
    rename table(:watchedlist), to: table(:watched_lists)

    alter table(:watched_lists) do
      add :user_id, references(:users, on_delete: :nothing)
      add :id_movie, :integer
    end

    create index(:watched_lists, [:user_id])
  end
end
