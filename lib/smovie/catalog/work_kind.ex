defmodule Smovie.Catalog.WorkKind do
  @moduledoc """
  Nature d'une oeuvre : film, serie, saison ou episode.
  """
  use Ecto.Type

  @values [:movie, :tv_show, :season, :episode]
  @roots [:movie, :tv_show]
  @children [:season, :episode]

  def values, do: @values

  @doc "Natures sans parent."
  def roots, do: @roots

  @doc "Natures qui ont forcement un parent."
  def children, do: @children

  @doc "Natures qu'on peut ajouter a une watchlist : on ne met pas un episode a voir."
  def watchlistable, do: @roots

  @impl true
  def type, do: :work_kind

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
end
