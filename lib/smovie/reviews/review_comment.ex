defmodule Smovie.Reviews.ReviewComment do
  @moduledoc """
  Commentaire sur une review.

  Un seul niveau de reponse : au-dela, un fil se lit mal sur un telephone, et
  l'indentation mange la largeur utile.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @max_length 2_000

  schema "review_comments" do
    field :body, :string
    field :likes_count, :integer, default: 0

    belongs_to :review, Smovie.Reviews.Review
    belongs_to :user, Smovie.Accounts.User
    belongs_to :parent, __MODULE__
    has_many :replies, __MODULE__, foreign_key: :parent_id

    timestamps(type: :utc_datetime)
  end

  def max_length, do: @max_length

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:review_id, :user_id, :parent_id, :body])
    |> validate_required([:review_id, :user_id, :body])
    |> update_change(:body, &String.trim/1)
    |> validate_length(:body, min: 1, max: @max_length)
    |> foreign_key_constraint(:review_id)
    |> foreign_key_constraint(:parent_id)
  end
end
