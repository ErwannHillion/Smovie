defmodule Smovie.Repo.Migrations.AddProfileFieldsToUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :username, :citext
      add :display_name, :string, size: 60
      add :bio, :text
      add :avatar_path, :string
      add :location, :string, size: 80
    end

    # Les comptes existants recoivent un username derive de leur adresse, et
    # un suffixe numerique en cas de collision. Sans cela, la contrainte NOT
    # NULL ci-dessous echouerait sur toute base non vide.
    execute """
    UPDATE users SET
      username = sub.candidate,
      display_name = COALESCE(NULLIF(split_part(email, '@', 1), ''), 'membre')
    FROM (
      SELECT id,
             CASE WHEN rn = 1 THEN base ELSE base || rn::text END AS candidate
        FROM (
          SELECT id, base,
                 row_number() OVER (PARTITION BY base ORDER BY id) AS rn
            FROM (
              SELECT id,
                     COALESCE(
                       NULLIF(regexp_replace(lower(split_part(email, '@', 1)), '[^a-z0-9_]', '', 'g'), ''),
                       'membre'
                     ) AS base
                FROM users
            ) normalized
        ) numbered
    ) sub
    WHERE users.id = sub.id;
    """

    alter table(:users) do
      modify :username, :citext, null: false
      modify :display_name, :string, size: 60, null: false
    end

    create unique_index(:users, [:username])
    create index(:users, [:display_name])

    create constraint(:users, :users_username_format,
             check: "username ~ '^[a-z0-9_]{3,30}$'"
           )
  end

  def down do
    drop constraint(:users, :users_username_format)
    drop index(:users, [:display_name])
    drop index(:users, [:username])

    alter table(:users) do
      remove :username
      remove :display_name
      remove :bio
      remove :avatar_path
      remove :location
    end
  end
end
