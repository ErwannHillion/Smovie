defmodule SmovieWeb.WatchLaterLiveTest do
  use SmovieWeb.ConnCase

  import Phoenix.LiveViewTest
  import Smovie.MoviesFixtures

  @create_attrs %{id_movie: 42, movie_description: "some movie_description", movie_title: "some movie_title"}
  @update_attrs %{id_movie: 43, movie_description: "some updated movie_description", movie_title: "some updated movie_title"}
  @invalid_attrs %{id_movie: nil, movie_description: nil, movie_title: nil}

  defp create_watch_later(_) do
    watch_later = watch_later_fixture()
    %{watch_later: watch_later}
  end

  describe "Index" do
    setup [:create_watch_later]

    test "lists all watchelater", %{conn: conn, watch_later: watch_later} do
      {:ok, _index_live, html} = live(conn, ~p"/watchelater")

      assert html =~ "Listing Watchelater"
      assert html =~ watch_later.movie_description
    end

    test "saves new watch_later", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/watchelater")

      assert index_live |> element("a", "New Watch later") |> render_click() =~
               "New Watch later"

      assert_patch(index_live, ~p"/watchelater/new")

      assert index_live
             |> form("#watch_later-form", watch_later: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#watch_later-form", watch_later: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/watchelater")

      html = render(index_live)
      assert html =~ "Watch later created successfully"
      assert html =~ "some movie_description"
    end

    test "updates watch_later in listing", %{conn: conn, watch_later: watch_later} do
      {:ok, index_live, _html} = live(conn, ~p"/watchelater")

      assert index_live |> element("#watchelater-#{watch_later.id} a", "Edit") |> render_click() =~
               "Edit Watch later"

      assert_patch(index_live, ~p"/watchelater/#{watch_later}/edit")

      assert index_live
             |> form("#watch_later-form", watch_later: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#watch_later-form", watch_later: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/watchelater")

      html = render(index_live)
      assert html =~ "Watch later updated successfully"
      assert html =~ "some updated movie_description"
    end

    test "deletes watch_later in listing", %{conn: conn, watch_later: watch_later} do
      {:ok, index_live, _html} = live(conn, ~p"/watchelater")

      assert index_live |> element("#watchelater-#{watch_later.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#watchelater-#{watch_later.id}")
    end
  end

  describe "Show" do
    setup [:create_watch_later]

    test "displays watch_later", %{conn: conn, watch_later: watch_later} do
      {:ok, _show_live, html} = live(conn, ~p"/watchelater/#{watch_later}")

      assert html =~ "Show Watch later"
      assert html =~ watch_later.movie_description
    end

    test "updates watch_later within modal", %{conn: conn, watch_later: watch_later} do
      {:ok, show_live, _html} = live(conn, ~p"/watchelater/#{watch_later}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Watch later"

      assert_patch(show_live, ~p"/watchelater/#{watch_later}/show/edit")

      assert show_live
             |> form("#watch_later-form", watch_later: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#watch_later-form", watch_later: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/watchelater/#{watch_later}")

      html = render(show_live)
      assert html =~ "Watch later updated successfully"
      assert html =~ "some updated movie_description"
    end
  end
end
