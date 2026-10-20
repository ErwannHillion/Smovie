defmodule Smovie.Repo.Migrations.AddPerformanceIndexes do
  use Ecto.Migration

  @moduledoc """
  Index tires des requetes reellement ecrites, et non d'une liste generique.

  Chaque index ci-dessous couvre une requete d'une page qui se charge a chaque
  visite : les ajouter au hasard couterait des ecritures sans rien accelerer.
  """

  def change do
    # list_recent_releases/2 : filtre sur (kind, release_date) puis trie par
    # popularite. L'index existant s'arrete au filtre et laissait un tri en
    # memoire sur tout le catalogue.
    create index(:works, [:kind, :release_date, :tmdb_popularity],
             name: :works_recent_releases_index
           )

    # list_watchlist/2 : tri par date d'ajout, avec l'identifiant en second
    # critere.
    create index(:watchlist_items, [:user_id, :inserted_at, :id],
             name: :watchlist_items_sorted_index
           )

    # list_by_user/3 et le profil : reviews d'un membre par visibilite.
    create index(:reviews, [:user_id, :visibility, :published_at],
             name: :reviews_user_visibility_index
           )

    # list_watched_works/2 : oeuvres vues d'un membre, dedoublonnees.
    create index(:watch_entries, [:user_id, :work_id], name: :watch_entries_user_work_index)

    # unread_by_conversation/1 : le badge de messages, lu a chaque page.
    create index(:messages, [:conversation_id, :sender_id, :id], name: :messages_unread_index)
  end
end
