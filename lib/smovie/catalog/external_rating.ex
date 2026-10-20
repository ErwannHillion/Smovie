defmodule Smovie.Catalog.ExternalRating do
  @moduledoc """
  Note d'une source exterieure a Smovie.

  L'echelle est stockee avec la note : 7,8 sur 10 et 78 sur 100 sont la meme
  appreciation, et les confondre a l'affichage serait grossier.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @sources [:imdb, :metacritic, :rotten_tomatoes, :tmdb, :allocine]

  schema "external_ratings" do
    field :source, Ecto.Enum, values: @sources
    field :score, :decimal
    field :scale, :integer
    field :votes_count, :integer
    field :url, :string
    field :fetched_at, :utc_datetime

    belongs_to :work, Smovie.Catalog.Work
  end

  def sources, do: @sources

  def changeset(rating, attrs) do
    rating
    |> cast(attrs, [:work_id, :source, :score, :scale, :votes_count, :url, :fetched_at])
    |> validate_required([:work_id, :source, :score, :scale, :fetched_at])
    |> validate_inclusion(:scale, [10, 100])
    |> validate_number(:score, greater_than_or_equal_to: 0)
    |> unique_constraint([:work_id, :source])
    |> foreign_key_constraint(:work_id)
  end

  @doc """
  Note ramenee sur 10, pour comparaison.
  """
  def out_of_ten(%__MODULE__{score: score, scale: 10}), do: Decimal.to_float(score)

  def out_of_ten(%__MODULE__{score: score, scale: 100}),
    do: score |> Decimal.div(10) |> Decimal.to_float()

  @doc """
  Libelle de la source, tel qu'il doit s'afficher.

  Les noms sont des marques : ils ne se traduisent pas et ne se raccourcissent
  pas. Afficher « RT » pour Rotten Tomatoes economiserait six caracteres au
  prix de la reconnaissance.
  """
  def label(:imdb), do: "IMDb"
  def label(:metacritic), do: "Metacritic"
  def label(:rotten_tomatoes), do: "Rotten Tomatoes"
  def label(:tmdb), do: "TMDB"
  def label(:allocine), do: "AlloCiné"
end
