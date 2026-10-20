defmodule Smovie.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def up do
    execute """
    CREATE TYPE notification_kind AS ENUM
      ('new_follower','review_liked','review_commented','comment_replied',
       'new_message','friend_rated_watchlist')
    """

    create table(:notifications) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :actor_id, references(:users, on_delete: :delete_all)
      add :kind, :notification_kind, null: false
      add :work_id, references(:works, on_delete: :delete_all)
      add :review_id, references(:reviews, on_delete: :delete_all)
      add :comment_id, references(:review_comments, on_delete: :delete_all)
      add :read_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:notifications, [:user_id, :inserted_at])
    # Index partiel : le badge de non-lus est la requete la plus frequente de
    # l'application, et il ne regarde que les lignes non lues.
    create index(:notifications, [:user_id],
             where: "read_at IS NULL",
             name: :notifications_unread_index
           )
  end

  def down do
    drop table(:notifications)
    execute "DROP TYPE notification_kind"
  end
end
