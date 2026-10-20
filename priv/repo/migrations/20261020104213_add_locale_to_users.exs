defmodule Smovie.Repo.Migrations.AddLocaleToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # Nullable a dessein : NULL signifie « suivre le navigateur », ce qui
      # n'est pas la meme chose que « choisir le francais ». Un compte cree
      # depuis un navigateur anglophone doit voir l'anglais sans avoir rien
      # regle, et continuer a le voir si la langue par defaut change.
      add :locale, :string, size: 8
    end
  end
end
