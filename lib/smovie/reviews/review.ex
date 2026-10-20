defmodule Smovie.Reviews.Review do
  @moduledoc """
  Critique d'un membre sur une oeuvre.

  Une review par membre et par oeuvre. C'est ce qui garantit que les cinq
  reviews populaires d'une fiche viennent de cinq personnes differentes : sans
  cette contrainte, un auteur prolixe les occuperait toutes.

  `rating_value` copie la note au moment de la publication. La review doit
  montrer la note qu'elle commente, meme si l'auteur la revoit ensuite.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias Smovie.Accounts.Visibility

  @min_length 1
  @max_length 10_000

  schema "reviews" do
    field :body, :string
    field :contains_spoilers, :boolean, default: false
    field :rating_value, :integer
    field :watched_on, :date
    field :visibility, Visibility, default: :public
    field :likes_count, :integer, default: 0
    field :comments_count, :integer, default: 0
    field :published_at, :utc_datetime

    belongs_to :user, Smovie.Accounts.User
    belongs_to :work, Smovie.Catalog.Work
    has_many :comments, Smovie.Reviews.ReviewComment
    has_many :likes, Smovie.Reviews.ReviewLike

    timestamps(type: :utc_datetime)
  end

  def max_length, do: @max_length

  def changeset(review, attrs) do
    review
    |> cast(attrs, [
      :user_id,
      :work_id,
      :body,
      :contains_spoilers,
      :rating_value,
      :watched_on,
      :visibility
    ])
    |> validate_required([:user_id, :work_id, :body])
    |> update_change(:body, &String.trim/1)
    |> validate_length(:body, min: @min_length, max: @max_length)
    |> validate_inclusion(:rating_value, 1..10)
    |> put_published_at()
    |> unique_constraint([:user_id, :work_id])
    |> check_constraint(:rating_value, name: :reviews_rating_range)
    |> foreign_key_constraint(:work_id)
  end

  defp put_published_at(changeset) do
    case get_field(changeset, :published_at) do
      nil -> put_change(changeset, :published_at, DateTime.utc_now(:second))
      _existing -> changeset
    end
  end

  @doc """
  Extrait d'une review, coupe sur un mot entier.

  Couper au caractere pres produirait des « incroyablem… » : la coupe sur
  l'espace precedent coute une ligne de code et se lit mieux.
  """
  def excerpt(%__MODULE__{body: body}, length \\ 220) do
    if String.length(body) <= length do
      body
    else
      body
      |> String.slice(0, length)
      |> String.replace(~r/\s+\S*$/u, "")
      |> Kernel.<>("…")
    end
  end
end
