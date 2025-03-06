defmodule Smovie.Repo.Migrations.AddUserIdToWatchelater do
  use Ecto.Migration

  def change do
    alter table(:watchelater) do
      add :user_id, references(:users, on_delete: :nothing)
    end

    create index(:watchelater, [:user_id])
  end
end
