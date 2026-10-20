defmodule Smovie.Library.WatchEntry do
  @moduledoc """
  Une seance : ce membre a vu cette oeuvre ce jour-la.

  Une entree par visionnage et non une ligne par (membre, oeuvre) : un
  re-visionnage s'ajoute a l'historique au lieu d'ecraser le precedent. C'est
  precisement ce que la table `user_movies` de l'ancienne version perdait.
  """
  use Ecto.Schema

  import Ecto.Changeset

  schema "watch_entries" do
    field :watched_on, :date
    field :rewatch, :boolean, default: false

    belongs_to :user, Smovie.Accounts.User
    belongs_to :work, Smovie.Catalog.Work

    timestamps(type: :utc_datetime)
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:user_id, :work_id, :watched_on, :rewatch])
    |> validate_required([:user_id, :work_id])
    |> put_watched_on()
    |> validate_not_in_future()
    |> unique_constraint([:user_id, :work_id, :watched_on])
    |> foreign_key_constraint(:work_id)
  end

  defp put_watched_on(changeset) do
    case get_field(changeset, :watched_on) do
      nil -> put_change(changeset, :watched_on, Date.utc_today())
      _existing -> changeset
    end
  end

  # Une date de visionnage dans le futur n'est pas un souvenir : c'est une
  # faute de saisie, et elle fausserait l'historique et les tendances.
  defp validate_not_in_future(changeset) do
    case get_field(changeset, :watched_on) do
      %Date{} = date ->
        if Date.after?(date, Date.utc_today()) do
          add_error(changeset, :watched_on, "ne peut pas etre dans le futur")
        else
          changeset
        end

      _other ->
        changeset
    end
  end
end
