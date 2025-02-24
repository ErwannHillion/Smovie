defmodule Smovie.Repo.Migrations.CreateWatchedlist do
  use Ecto.Migration

  def change do
    create table(:watchedlist) do
      add :urating, :float
      add :udescription, :string
      add :uwatcheddate, :date
      add :user, references(:users, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:watchedlist, [:user])
  end
end
