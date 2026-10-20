defmodule Smovie.Library.Rating do
  @moduledoc """
  Note d'un membre sur une oeuvre.

  `value` est le **nombre de demi-etoiles**, de 1 a 10 : 1 vaut une demi-etoile,
  10 vaut cinq etoiles. Un entier et non un flottant — pas d'arrondi parasite,
  et une agregation exacte.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @min 1
  @max 10

  schema "ratings" do
    field :value, :integer
    field :rated_at, :utc_datetime

    belongs_to :user, Smovie.Accounts.User
    belongs_to :work, Smovie.Catalog.Work

    timestamps(type: :utc_datetime)
  end

  def min_value, do: @min
  def max_value, do: @max

  def changeset(rating, attrs) do
    rating
    |> cast(attrs, [:user_id, :work_id, :value, :rated_at])
    |> validate_required([:user_id, :work_id, :value])
    |> put_rated_at()
    |> validate_number(:value, greater_than_or_equal_to: @min, less_than_or_equal_to: @max)
    |> unique_constraint([:user_id, :work_id])
    |> check_constraint(:value, name: :ratings_value_range)
    |> foreign_key_constraint(:work_id)
  end

  defp put_rated_at(changeset) do
    case get_field(changeset, :rated_at) do
      nil -> put_change(changeset, :rated_at, DateTime.utc_now(:second))
      _existing -> changeset
    end
  end

  @doc """
  Convertit des demi-etoiles en note sur 5.

      iex> Smovie.Library.Rating.to_stars(7)
      3.5
  """
  def to_stars(half_stars) when is_integer(half_stars), do: half_stars / 2

  @doc """
  Convertit une note sur 5 en demi-etoiles.
  """
  def from_stars(stars) when is_number(stars), do: round(stars * 2)
end
