defmodule Smovie.MoviesTest do
  use Smovie.DataCase

  alias Smovie.Movies

  describe "watchedlist" do
    alias Smovie.Movies.WatchedList

    import Smovie.MoviesFixtures

    @invalid_attrs %{urating: nil, udescription: nil, uwatcheddate: nil}

    test "list_watchedlist/0 returns all watchedlist" do
      watched_list = watched_list_fixture()
      assert Movies.list_watchedlist() == [watched_list]
    end

    test "get_watched_list!/1 returns the watched_list with given id" do
      watched_list = watched_list_fixture()
      assert Movies.get_watched_list!(watched_list.id) == watched_list
    end

    test "create_watched_list/1 with valid data creates a watched_list" do
      valid_attrs = %{urating: 120.5, udescription: "some udescription", uwatcheddate: ~D[2025-02-23]}

      assert {:ok, %WatchedList{} = watched_list} = Movies.create_watched_list(valid_attrs)
      assert watched_list.urating == 120.5
      assert watched_list.udescription == "some udescription"
      assert watched_list.uwatcheddate == ~D[2025-02-23]
    end

    test "create_watched_list/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Movies.create_watched_list(@invalid_attrs)
    end

    test "update_watched_list/2 with valid data updates the watched_list" do
      watched_list = watched_list_fixture()
      update_attrs = %{urating: 456.7, udescription: "some updated udescription", uwatcheddate: ~D[2025-02-24]}

      assert {:ok, %WatchedList{} = watched_list} = Movies.update_watched_list(watched_list, update_attrs)
      assert watched_list.urating == 456.7
      assert watched_list.udescription == "some updated udescription"
      assert watched_list.uwatcheddate == ~D[2025-02-24]
    end

    test "update_watched_list/2 with invalid data returns error changeset" do
      watched_list = watched_list_fixture()
      assert {:error, %Ecto.Changeset{}} = Movies.update_watched_list(watched_list, @invalid_attrs)
      assert watched_list == Movies.get_watched_list!(watched_list.id)
    end

    test "delete_watched_list/1 deletes the watched_list" do
      watched_list = watched_list_fixture()
      assert {:ok, %WatchedList{}} = Movies.delete_watched_list(watched_list)
      assert_raise Ecto.NoResultsError, fn -> Movies.get_watched_list!(watched_list.id) end
    end

    test "change_watched_list/1 returns a watched_list changeset" do
      watched_list = watched_list_fixture()
      assert %Ecto.Changeset{} = Movies.change_watched_list(watched_list)
    end
  end

  describe "watchelater" do
    alias Smovie.Movies.WatchLater

    import Smovie.MoviesFixtures

    @invalid_attrs %{id_movie: nil, movie_description: nil, movie_title: nil}

    test "list_watchelater/0 returns all watchelater" do
      watch_later = watch_later_fixture()
      assert Movies.list_watchelater() == [watch_later]
    end

    test "get_watch_later!/1 returns the watch_later with given id" do
      watch_later = watch_later_fixture()
      assert Movies.get_watch_later!(watch_later.id) == watch_later
    end

    test "create_watch_later/1 with valid data creates a watch_later" do
      valid_attrs = %{id_movie: 42, movie_description: "some movie_description", movie_title: "some movie_title"}

      assert {:ok, %WatchLater{} = watch_later} = Movies.create_watch_later(valid_attrs)
      assert watch_later.id_movie == 42
      assert watch_later.movie_description == "some movie_description"
      assert watch_later.movie_title == "some movie_title"
    end

    test "create_watch_later/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Movies.create_watch_later(@invalid_attrs)
    end

    test "update_watch_later/2 with valid data updates the watch_later" do
      watch_later = watch_later_fixture()
      update_attrs = %{id_movie: 43, movie_description: "some updated movie_description", movie_title: "some updated movie_title"}

      assert {:ok, %WatchLater{} = watch_later} = Movies.update_watch_later(watch_later, update_attrs)
      assert watch_later.id_movie == 43
      assert watch_later.movie_description == "some updated movie_description"
      assert watch_later.movie_title == "some updated movie_title"
    end

    test "update_watch_later/2 with invalid data returns error changeset" do
      watch_later = watch_later_fixture()
      assert {:error, %Ecto.Changeset{}} = Movies.update_watch_later(watch_later, @invalid_attrs)
      assert watch_later == Movies.get_watch_later!(watch_later.id)
    end

    test "delete_watch_later/1 deletes the watch_later" do
      watch_later = watch_later_fixture()
      assert {:ok, %WatchLater{}} = Movies.delete_watch_later(watch_later)
      assert_raise Ecto.NoResultsError, fn -> Movies.get_watch_later!(watch_later.id) end
    end

    test "change_watch_later/1 returns a watch_later changeset" do
      watch_later = watch_later_fixture()
      assert %Ecto.Changeset{} = Movies.change_watch_later(watch_later)
    end
  end
end
