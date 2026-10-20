defmodule Smovie.Repo.Migrations.CreateFollows do
  use Ecto.Migration

  def change do
    create table(:follows) do
      add :follower_id, references(:users, on_delete: :delete_all), null: false
      add :followed_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:follows, [:follower_id, :followed_id])
    create index(:follows, [:followed_id])

    # La validation applicative seule laisserait passer une insertion directe
    # ou une course : un compte ne doit jamais pouvoir se suivre lui-meme.
    create constraint(:follows, :follows_not_self, check: "follower_id <> followed_id")

    alter table(:users) do
      add :followers_count, :integer, null: false, default: 0
      add :following_count, :integer, null: false, default: 0
    end
  end
end
