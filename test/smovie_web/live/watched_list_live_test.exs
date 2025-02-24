defmodule SmovieWeb.WatchedListLiveTest do
  use SmovieWeb.ConnCase

  import Phoenix.LiveViewTest
  import Smovie.MoviesFixtures

  @create_attrs %{urating: 120.5, udescription: "some udescription", uwatcheddate: "2025-02-23"}
  @update_attrs %{urating: 456.7, udescription: "some updated udescription", uwatcheddate: "2025-02-24"}
  @invalid_attrs %{urating: nil, udescription: nil, uwatcheddate: nil}

  defp create_watched_list(_) do
    watched_list = watched_list_fixture()
    %{watched_list: watched_list}
  end

  describe "Index" do
    setup [:create_watched_list]

    test "lists all watchedlist", %{conn: conn, watched_list: watched_list} do
      {:ok, _index_live, html} = live(conn, ~p"/watchedlist")

      assert html =~ "Listing Watchedlist"
      assert html =~ watched_list.udescription
    end

    test "saves new watched_list", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/watchedlist")

      assert index_live |> element("a", "New Watched list") |> render_click() =~
               "New Watched list"

      assert_patch(index_live, ~p"/watchedlist/new")

      assert index_live
             |> form("#watched_list-form", watched_list: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#watched_list-form", watched_list: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/watchedlist")

      html = render(index_live)
      assert html =~ "Watched list created successfully"
      assert html =~ "some udescription"
    end

    test "updates watched_list in listing", %{conn: conn, watched_list: watched_list} do
      {:ok, index_live, _html} = live(conn, ~p"/watchedlist")

      assert index_live |> element("#watchedlist-#{watched_list.id} a", "Edit") |> render_click() =~
               "Edit Watched list"

      assert_patch(index_live, ~p"/watchedlist/#{watched_list}/edit")

      assert index_live
             |> form("#watched_list-form", watched_list: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#watched_list-form", watched_list: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/watchedlist")

      html = render(index_live)
      assert html =~ "Watched list updated successfully"
      assert html =~ "some updated udescription"
    end

    test "deletes watched_list in listing", %{conn: conn, watched_list: watched_list} do
      {:ok, index_live, _html} = live(conn, ~p"/watchedlist")

      assert index_live |> element("#watchedlist-#{watched_list.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#watchedlist-#{watched_list.id}")
    end
  end

  describe "Show" do
    setup [:create_watched_list]

    test "displays watched_list", %{conn: conn, watched_list: watched_list} do
      {:ok, _show_live, html} = live(conn, ~p"/watchedlist/#{watched_list}")

      assert html =~ "Show Watched list"
      assert html =~ watched_list.udescription
    end

    test "updates watched_list within modal", %{conn: conn, watched_list: watched_list} do
      {:ok, show_live, _html} = live(conn, ~p"/watchedlist/#{watched_list}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Watched list"

      assert_patch(show_live, ~p"/watchedlist/#{watched_list}/show/edit")

      assert show_live
             |> form("#watched_list-form", watched_list: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#watched_list-form", watched_list: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/watchedlist/#{watched_list}")

      html = render(show_live)
      assert html =~ "Watched list updated successfully"
      assert html =~ "some updated udescription"
    end
  end
end
