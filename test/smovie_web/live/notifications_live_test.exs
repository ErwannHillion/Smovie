defmodule SmovieWeb.NotificationsLiveTest do
  use SmovieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Smovie.AccountsFixtures
  import Smovie.CatalogFixtures
  import Smovie.ReviewsFixtures

  alias Smovie.Accounts.Scope
  alias Smovie.Reviews
  alias Smovie.Social

  setup do
    auteur = user_fixture()
    lecteur = user_fixture()
    review = review_fixture(auteur, movie_fixture())
    Reviews.toggle_like(Scope.for_user(lecteur), review)

    %{auteur: auteur, lecteur: lecteur, review: review}
  end

  test "liste les notifications", %{conn: conn, auteur: auteur} do
    {:ok, _lv, html} = conn |> log_in_user(auteur) |> live(~p"/notifications")

    assert html =~ "a aime votre review"
  end

  test "le badge affiche le nombre de non-lues", %{conn: conn, auteur: auteur} do
    {:ok, lv, html} = conn |> log_in_user(auteur) |> live(~p"/")

    assert html =~ ~s(aria-label="Notifications")
    assert lv |> element(~s([data-role="unread-badge"])) |> render() =~ "1"
  end

  test "le badge disparait une fois tout lu", %{conn: conn, auteur: auteur} do
    {:ok, lv, _html} = conn |> log_in_user(auteur) |> live(~p"/notifications")
    lv |> element(~s(button[phx-click="mark_all_read"])) |> render_click()

    {:ok, accueil, _html} = conn |> log_in_user(auteur) |> live(~p"/")

    refute has_element?(accueil, ~s([data-role="unread-badge"]))
  end

  test "tout marquer comme lu eteint le badge", %{conn: conn, auteur: auteur} do
    {:ok, lv, _html} = conn |> log_in_user(auteur) |> live(~p"/notifications")

    lv |> element(~s(button[phx-click="mark_all_read"])) |> render_click()

    assert Social.unread_count(Scope.for_user(auteur)) == 0
  end

  test "un membre sans notification le voit", %{conn: conn, lecteur: lecteur} do
    {:ok, _lv, html} = conn |> log_in_user(lecteur) |> live(~p"/notifications")

    assert html =~ "Aucune notification"
  end
end
