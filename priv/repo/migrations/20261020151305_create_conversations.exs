defmodule Smovie.Repo.Migrations.CreateConversations do
  use Ecto.Migration

  def up do
    execute "CREATE TYPE conversation_kind AS ENUM ('direct','group')"
    execute "CREATE TYPE member_role AS ENUM ('owner','admin','member')"
    execute "CREATE TYPE message_kind AS ENUM ('text','work_share','review_share','system')"

    create table(:conversations) do
      add :kind, :conversation_kind, null: false
      add :title, :string, size: 120
      add :created_by_id, references(:users, on_delete: :nilify_all)
      # Cle d'unicite d'une conversation privee : "<min_id>:<max_id>". Sans
      # elle, deux clics simultanes sur « Envoyer un message » creeraient deux
      # conversations entre les memes personnes.
      add :direct_key, :string, size: 40
      add :last_message_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:conversations, [:direct_key])
    create index(:conversations, [:last_message_at])

    create constraint(:conversations, :conversations_direct_key,
             check: "(kind = 'direct') = (direct_key IS NOT NULL)"
           )

    create table(:conversation_members) do
      add :conversation_id, references(:conversations, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :role, :member_role, null: false, default: "member"
      add :last_read_message_id, :bigint
      add :muted_until, :utc_datetime
      add :joined_at, :utc_datetime, null: false
      add :left_at, :utc_datetime
    end

    create unique_index(:conversation_members, [:conversation_id, :user_id])
    create index(:conversation_members, [:user_id])

    create table(:messages) do
      add :conversation_id, references(:conversations, on_delete: :delete_all), null: false
      add :sender_id, references(:users, on_delete: :nilify_all)
      add :kind, :message_kind, null: false, default: "text"
      add :body, :text
      add :shared_work_id, references(:works, on_delete: :nilify_all)
      add :shared_review_id, references(:reviews, on_delete: :nilify_all)
      add :reply_to_id, references(:messages, on_delete: :nilify_all)
      add :edited_at, :utc_datetime
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    # Pagination par curseur sur l'identifiant, jamais par OFFSET : un fil
    # ancien coute alors le meme prix qu'un fil recent.
    create index(:messages, [:conversation_id, :id])

    # Un message supprime perd son corps mais garde sa ligne : la bulle
    # « message supprime » garde le fil lisible, la ou un trou laisserait
    # croire a un bug.
    create constraint(:messages, :messages_text_body,
             check: "kind <> 'text' OR body IS NOT NULL OR deleted_at IS NOT NULL"
           )

    create constraint(:messages, :messages_work_share,
             check: "(kind = 'work_share') = (shared_work_id IS NOT NULL)"
           )

    create constraint(:messages, :messages_review_share,
             check: "(kind = 'review_share') = (shared_review_id IS NOT NULL)"
           )
  end

  def down do
    drop table(:messages)
    drop table(:conversation_members)
    drop table(:conversations)
    execute "DROP TYPE message_kind"
    execute "DROP TYPE member_role"
    execute "DROP TYPE conversation_kind"
  end
end
