defmodule Smovie.Accounts.Visibility do
  @moduledoc """
  Reglage de visibilite d'une donnee de profil.

  Trois valeurs : `:public`, `:followers`, `:private`.

  La decision d'autorisation vit ici plutot que dans chaque LiveView : trois
  reglages multiplies par autant d'ecrans, c'est exactement le genre de regle
  qu'on finit par ecrire differemment a deux endroits.
  """
  use Ecto.Type

  @values [:public, :followers, :private]

  def values, do: @values

  @impl true
  def type, do: :visibility

  @impl true
  def cast(value) when value in @values, do: {:ok, value}

  def cast(value) when is_binary(value) do
    case Enum.find(@values, &(Atom.to_string(&1) == value)) do
      nil -> :error
      found -> {:ok, found}
    end
  end

  def cast(_value), do: :error

  @impl true
  def load(value) when is_binary(value), do: cast(value)
  def load(_value), do: :error

  @impl true
  def dump(value) when value in @values, do: {:ok, Atom.to_string(value)}
  def dump(_value), do: :error

  @doc """
  Libelle traduit d'un reglage.
  """
  def label(:public), do: Gettext.gettext(SmovieWeb.Gettext, "Public")
  def label(:followers), do: Gettext.gettext(SmovieWeb.Gettext, "Abonnes seulement")
  def label(:private), do: Gettext.gettext(SmovieWeb.Gettext, "Prive")

  @doc """
  Options d'un `<select>`, dans l'ordre du plus ouvert au plus ferme.
  """
  def options, do: Enum.map(@values, &{label(&1), &1})
end
