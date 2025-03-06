defmodule Smovie.Repo.Migrations.CreateWatchelater do
  use Ecto.Migration

  def change do
    create table(:watchelater) do
      add :id_movie, :integer
      add :movie_description, :string
      add :movie_title, :string
      add :user, references(:users, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:watchelater, [:user])
  end
end
