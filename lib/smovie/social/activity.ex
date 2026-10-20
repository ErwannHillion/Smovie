defmodule Smovie.Social.Activity do
  @moduledoc """
  Une action visible par les abonnes de son auteur.

  Le fil se construit **a la lecture** : une ligne par action, filtree sur le
  graphe d'abonnements. Dupliquer chaque action chez tous les abonnes ferait
  exploser la table au premier compte un peu suivi, pour un service qui n'a
  pas ce probleme.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @kinds [:rated, :watched, :reviewed, :liked_work, :followed]

  schema "activities" do
    field :kind, Ecto.Enum, values: @kinds
    field :rating_value, :integer

    belongs_to :user, Smovie.Accounts.User
    belongs_to :target_user, Smovie.Accounts.User
    belongs_to :work, Smovie.Catalog.Work
    belongs_to :review, Smovie.Reviews.Review

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def kinds, do: @kinds

  def changeset(activity, attrs) do
    activity
    |> cast(attrs, [:user_id, :kind, :work_id, :review_id, :target_user_id, :rating_value])
    |> validate_required([:user_id, :kind])
    |> validate_subject()
    |> foreign_key_constraint(:work_id)
    |> foreign_key_constraint(:review_id)
  end

  # Une activite sans sujet ne s'affiche pas : autant la refuser a l'ecriture
  # plutot que de la filtrer a chaque lecture.
  defp validate_subject(changeset) do
    case get_field(changeset, :kind) do
      :followed -> validate_required(changeset, [:target_user_id])
      nil -> changeset
      _work_kind -> validate_required(changeset, [:work_id])
    end
  end
end
