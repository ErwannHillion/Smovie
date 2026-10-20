defmodule Smovie.Repo.Migrations.CreateWatchlistItems do
  use Ecto.Migration

  def change do
    create table(:watchlist_items) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :work_id, references(:works, on_delete: :delete_all), null: false
      add :note, :string, size: 280

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:watchlist_items, [:user_id, :work_id])
    create index(:watchlist_items, [:user_id, :inserted_at])
  end
end
