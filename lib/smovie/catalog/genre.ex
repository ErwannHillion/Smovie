defmodule Smovie.Catalog.Genre do
  @moduledoc "Genre d'une oeuvre, tel que TMDB les nomme."
  use Ecto.Schema

  import Ecto.Changeset

  alias Smovie.Catalog.Slug

  schema "genres" do
    field :tmdb_id, :integer
    field :name, :string
    field :slug, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(genre, attrs) do
    genre
    |> cast(attrs, [:tmdb_id, :name])
    |> validate_required([:tmdb_id, :name])
    |> put_slug()
    |> unique_constraint(:tmdb_id)
    |> unique_constraint(:slug)
  end

  defp put_slug(changeset) do
    case get_change(changeset, :name) do
      nil -> changeset
      name -> put_change(changeset, :slug, Slug.slugify(name))
    end
  end
end
