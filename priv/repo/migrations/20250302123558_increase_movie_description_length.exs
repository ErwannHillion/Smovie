defmodule Smovie.Repo.Migrations.IncreaseMovieDescriptionLength do
  use Ecto.Migration

  def change do
    alter table(:watchelater) do
      modify :movie_description, :string, size: 1000
    end
  end
end
