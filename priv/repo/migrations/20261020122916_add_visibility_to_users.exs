defmodule Smovie.Repo.Migrations.AddVisibilityToUsers do
  use Ecto.Migration

  def up do
    # Type enumere plutot qu'une chaine : la base refuse alors une valeur
    # inventee, et la liste des valeurs est lisible depuis le schema.
    execute "CREATE TYPE visibility AS ENUM ('public','followers','private')"

    alter table(:users) do
      add :profile_visibility, :visibility, null: false, default: "public"
      add :watchlist_visibility, :visibility, null: false, default: "public"
      add :default_review_visibility, :visibility, null: false, default: "public"
    end
  end

  def down do
    alter table(:users) do
      remove :profile_visibility
      remove :watchlist_visibility
      remove :default_review_visibility
    end

    execute "DROP TYPE visibility"
  end
end
