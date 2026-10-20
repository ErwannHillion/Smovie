defmodule Smovie.Catalog.Person do
  @moduledoc "Une personne : interprete ou membre de l'equipe technique."
  use Ecto.Schema

  import Ecto.Changeset

  alias Smovie.Catalog.Slug

  schema "people" do
    field :tmdb_id, :integer
    field :name, :string
    field :slug, :string
    field :profile_path, :string
    field :known_for_department, :string
    field :birthday, :date
    field :deathday, :date
    field :biography, :string

    has_many :credits, Smovie.Catalog.Credit

    timestamps(type: :utc_datetime)
  end

  @fields [
    :tmdb_id,
    :name,
    :profile_path,
    :known_for_department,
    :birthday,
    :deathday,
    :biography
  ]

  def changeset(person, attrs) do
    person
    |> cast(attrs, [:slug | @fields])
    |> validate_required([:tmdb_id, :name])
    |> validate_length(:name, max: 200)
    |> put_slug()
    |> unique_constraint(:tmdb_id)
    |> unique_constraint(:slug)
  end

  defp put_slug(changeset) do
    case {get_field(changeset, :slug), get_change(changeset, :name)} do
      {nil, nil} -> changeset
      # Le slug inclut l'identifiant TMDB : deux homonymes existent, et un
      # suffixe numerique arbitraire serait moins stable.
      {nil, name} -> put_change(changeset, :slug, person_slug(changeset, name))
      _existing -> changeset
    end
  end

  defp person_slug(changeset, name) do
    "#{Slug.slugify(name)}-#{get_field(changeset, :tmdb_id)}"
  end

  @doc "Chemin public d'une personne."
  def path(%__MODULE__{slug: slug}), do: "/personne/#{slug}"
end
