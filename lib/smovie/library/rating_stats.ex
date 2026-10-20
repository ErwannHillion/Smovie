defmodule Smovie.Library.RatingStats do
  @moduledoc """
  Moyenne de la plateforme, dans une table d'une seule ligne.

  Elle sert d'a priori a la moyenne bayesienne. La recalculer a chaque note
  serait un scan complet de `ratings` ; un job horaire suffit, la moyenne
  globale ne bougeant que tres lentement.
  """
  use Ecto.Schema

  @primary_key {:id, :boolean, autogenerate: false}
  schema "rating_stats" do
    field :global_average, :decimal
    field :ratings_count, :integer
    field :computed_at, :utc_datetime
  end
end
