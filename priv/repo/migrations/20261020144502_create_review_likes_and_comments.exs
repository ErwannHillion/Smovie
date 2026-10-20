defmodule Smovie.Repo.Migrations.CreateReviewLikesAndComments do
  use Ecto.Migration

  def change do
    create table(:review_likes) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :review_id, references(:reviews, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:review_likes, [:user_id, :review_id])
    create index(:review_likes, [:review_id])

    create table(:review_comments) do
      add :review_id, references(:reviews, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      # Un seul niveau de reponse : au-dela, un fil se lit mal sur un
      # telephone, et l'indentation mange la largeur utile.
      add :parent_id, references(:review_comments, on_delete: :delete_all)
      add :body, :text, null: false
      add :likes_count, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:review_comments, [:review_id, :inserted_at])
    create index(:review_comments, [:parent_id])

    create table(:comment_likes) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :comment_id, references(:review_comments, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:comment_likes, [:user_id, :comment_id])
  end
end
