defmodule Smovie.Catalog.Credit do
  @moduledoc """
  Participation d'une personne a une oeuvre.

  Une meme personne peut apparaitre deux fois sur la meme oeuvre : realisatrice
  et scenariste, ou interprete de deux roles. La cle d'unicite inclut donc le
  poste et le personnage.
  """
  use Ecto.Schema

  import Ecto.Changeset

  schema "credits" do
    field :kind, Ecto.Enum, values: [:cast, :crew]
    field :department, :string
    field :job, :string
    field :character, :string
    field :display_order, :integer

    belongs_to :work, Smovie.Catalog.Work
    belongs_to :person, Smovie.Catalog.Person
  end

  def changeset(credit, attrs) do
    credit
    |> cast(attrs, [
      :work_id,
      :person_id,
      :kind,
      :department,
      :job,
      :character,
      :display_order
    ])
    |> validate_required([:work_id, :person_id, :kind])
    |> foreign_key_constraint(:work_id)
    |> foreign_key_constraint(:person_id)
    |> unique_constraint([:work_id, :person_id, :kind, :job, :character], name: :credits_unique)
  end
end
