defmodule Smovie.Movies do
  @moduledoc """
  The Movies context.
  """

  import Ecto.Query, warn: false
  alias Smovie.Repo

  alias Smovie.Movies.WatchedList

  @doc """
  Returns the list of watchedlist.

  ## Examples

      iex> list_watchedlist()
      [%WatchedList{}, ...]

  """
  def list_watchedlist do
    Repo.all(WatchedList)
  end

  def list_watched_lists_for_user(user_id) do
    Repo.all(from w in WatchedList, where: w.user_id == ^user_id)
  end

  @doc """
  Gets a single watched_list.

  Raises `Ecto.NoResultsError` if the Watched list does not exist.

  ## Examples

      iex> get_watched_list!(123)
      %WatchedList{}

      iex> get_watched_list!(456)
      ** (Ecto.NoResultsError)

  """
  def get_watched_list!(id), do: Repo.get!(WatchedList, id)

  @doc """
  Creates a watched_list.

  ## Examples

      iex> create_watched_list(%{field: value})
      {:ok, %WatchedList{}}

      iex> create_watched_list(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_watched_list(attrs \\ %{}) do
    %WatchedList{}
    |> WatchedList.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a watched_list.

  ## Examples

      iex> update_watched_list(watched_list, %{field: new_value})
      {:ok, %WatchedList{}}

      iex> update_watched_list(watched_list, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_watched_list(%WatchedList{} = watched_list, attrs) do
    watched_list
    |> WatchedList.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a watched_list.

  ## Examples

      iex> delete_watched_list(watched_list)
      {:ok, %WatchedList{}}

      iex> delete_watched_list(watched_list)
      {:error, %Ecto.Changeset{}}

  """
  def delete_watched_list(%WatchedList{} = watched_list) do
    Repo.delete(watched_list)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking watched_list changes.

  ## Examples

      iex> change_watched_list(watched_list)
      %Ecto.Changeset{data: %WatchedList{}}

  """
  def change_watched_list(%WatchedList{} = watched_list, attrs \\ %{}) do
    WatchedList.changeset(watched_list, attrs)
  end
end
