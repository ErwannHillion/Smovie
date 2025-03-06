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

  alias Smovie.Movies.WatchLater

  @doc """
  Returns the list of watchelater.

  ## Examples

      iex> list_watchelater()
      [%WatchLater{}, ...]

  """
  def list_watchelater do
    Repo.all(WatchLater)
  end

  def list_watch_later_for_user(user_id) do
    Repo.all(from wl in WatchLater, where: wl.user_id == ^user_id)
  end

  @doc """
  Gets a single watch_later.

  Raises `Ecto.NoResultsError` if the Watch later does not exist.

  ## Examples

      iex> get_watch_later!(123)
      %WatchLater{}

      iex> get_watch_later!(456)
      ** (Ecto.NoResultsError)

  """
  def get_watch_later!(id), do: Repo.get!(WatchLater, id)

  @doc """
  Creates a watch_later.

  ## Examples

      iex> create_watch_later(%{field: value})
      {:ok, %WatchLater{}}

      iex> create_watch_later(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_watch_later(attrs \\ %{}) do
    %WatchLater{}
    |> WatchLater.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a watch_later.

  ## Examples

      iex> update_watch_later(watch_later, %{field: new_value})
      {:ok, %WatchLater{}}

      iex> update_watch_later(watch_later, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_watch_later(%WatchLater{} = watch_later, attrs) do
    watch_later
    |> WatchLater.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a watch_later.

  ## Examples

      iex> delete_watch_later(watch_later)
      {:ok, %WatchLater{}}

      iex> delete_watch_later(watch_later)
      {:error, %Ecto.Changeset{}}

  """
  def delete_watch_later(%WatchLater{} = watch_later) do
    Repo.delete(watch_later)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking watch_later changes.

  ## Examples

      iex> change_watch_later(watch_later)
      %Ecto.Changeset{data: %WatchLater{}}

  """
  def change_watch_later(%WatchLater{} = watch_later, attrs \\ %{}) do
    WatchLater.changeset(watch_later, attrs)
  end
end
