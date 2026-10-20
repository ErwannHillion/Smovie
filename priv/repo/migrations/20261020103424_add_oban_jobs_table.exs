defmodule Smovie.Repo.Migrations.AddObanJobsTable do
  use Ecto.Migration

  def up do
    Oban.Migration.up(version: 12)
  end

  # La version 1 est la plus ancienne : le rollback supprime entierement les
  # tables d'Oban.
  def down do
    Oban.Migration.down(version: 1)
  end
end
