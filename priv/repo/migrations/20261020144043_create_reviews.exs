defmodule Smovie.Repo.Migrations.CreateReviews do
  use Ecto.Migration

  def change do
    create table(:reviews) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :work_id, references(:works, on_delete: :delete_all), null: false
      add :body, :text, null: false
      add :contains_spoilers, :boolean, null: false, default: false
      # Copie de la note au moment de la publication : la review doit montrer
      # la note qu'elle commente, meme si l'auteur la change ensuite.
      add :rating_value, :smallint
      add :watched_on, :date
      add :visibility, :visibility, null: false, default: "public"
      add :likes_count, :integer, null: false, default: 0
      add :comments_count, :integer, null: false, default: 0
      add :published_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    # Une review par membre et par oeuvre : c'est ce qui garantit que les cinq
    # reviews populaires d'une fiche viennent de cinq personnes differentes.
    create unique_index(:reviews, [:user_id, :work_id])
    create index(:reviews, [:user_id, :published_at])

    create index(:reviews, [:work_id, :likes_count, :published_at],
             where: "visibility = 'public'",
             name: :reviews_work_popular_index
           )

    create index(:reviews, [:published_at],
             where: "visibility = 'public'",
             name: :reviews_published_index
           )

    create constraint(:reviews, :reviews_rating_range,
             check: "rating_value IS NULL OR rating_value BETWEEN 1 AND 10"
           )

    alter table(:works) do
      modify :smovie_review_count, :integer, null: false, default: 0
    end
  end
end
