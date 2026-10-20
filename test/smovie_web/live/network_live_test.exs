defmodule SmovieWeb.NetworkLiveTest do
  use SmovieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Smovie.AccountsFixtures

  alias Smovie.Accounts
  alias Smovie.Accounts.Scope
  alias Smovie.Social

  setup do
    moi = user_fixture()
    autre = user_fixture()

    {:ok, moi} =
      Accounts.update_user_profile(Scope.for_user(moi), moi, %{
        "username" => "lea",
        "display_name" => "Lea"
      })

    {:ok, autre} =
      Accounts.update_user_profile(Scope.for_user(autre), autre, %{
        "username" => "autre",
        "display_name" => "Autre"
      })

    %{moi: moi, autre: autre}
  end

  test "le profil affiche les compteurs", %{conn: conn, moi: moi, autre: autre} do
    Social.follow(Scope.for_user(moi), autre)

    {:ok, _lv, html} = live(conn, ~p"/u/autre")

    assert html =~ "abonnes"
    assert html =~ "abonnements"
  end

  test "suivre depuis le profil", %{conn: conn, moi: moi, autre: autre} do
    {:ok, lv, _html} = conn |> log_in_user(moi) |> live(~p"/u/autre")

    html = lv |> element(~s(button[phx-click="toggle_follow"])) |> render_click()

    assert html =~ "Abonne"
    assert Social.following?(Scope.for_user(moi), autre)
  end

  test "pas de bouton d'abonnement sur son propre profil", %{conn: conn, moi: moi} do
    {:ok, _lv, html} = conn |> log_in_user(moi) |> live(~p"/u/lea")

    refute html =~ ~s(phx-click="toggle_follow")
    assert html =~ "Modifier mon profil"
  end

  test "un visiteur est renvoye vers la connexion", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/u/autre")

    assert {:error, {:live_redirect, %{to: "/users/log-in"}}} =
             lv |> element(~s(button[phx-click="toggle_follow"])) |> render_click()
  end

  test "la page abonnements liste les suivis", %{conn: conn, moi: moi, autre: autre} do
    Social.follow(Scope.for_user(moi), autre)

    {:ok, _lv, html} = live(conn, ~p"/u/lea/abonnements")

    assert html =~ "Autre"
    assert html =~ "@autre"
  end

  test "la page abonnes liste les abonnes", %{conn: conn, moi: moi, autre: autre} do
    Social.follow(Scope.for_user(moi), autre)

    {:ok, _lv, html} = live(conn, ~p"/u/autre/abonnes")

    assert html =~ "@lea"
  end

  test "une liste vide le dit", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/u/lea/abonnements")

    assert html =~ "ne suit personne"
  end

  test "on ne se propose pas de se suivre soi-meme", %{conn: conn, moi: moi, autre: autre} do
    Social.follow(Scope.for_user(autre), moi)

    {:ok, _lv, html} = conn |> log_in_user(moi) |> live(~p"/u/lea/abonnes")

    refute html =~ ~s(phx-value-user-id="#{moi.id}")
  end
end
