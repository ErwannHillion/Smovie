defmodule SmovieWeb.ProfileLiveTest do
  use SmovieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Smovie.AccountsFixtures

  alias Smovie.Accounts
  alias Smovie.Accounts.Scope

  setup do
    user = user_fixture()

    {:ok, user} =
      Accounts.update_user_profile(Scope.for_user(user), user, %{
        "username" => "cinephile",
        "display_name" => "Cinephile",
        "bio" => "Villeneuve, Lanthimos, et le cinema japonais contemplatif.",
        "location" => "Montpellier"
      })

    %{user: user}
  end

  test "affiche le profil public d'un membre", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/u/cinephile")

    assert html =~ "Cinephile"
    assert html =~ "@cinephile"
    assert html =~ "Montpellier"
    assert html =~ "cinema japonais contemplatif"
  end

  test "l'adresse e-mail n'apparait pas sur le profil public", %{conn: conn, user: user} do
    {:ok, _lv, html} = live(conn, ~p"/u/cinephile")

    refute html =~ user.email
  end

  test "un username inconnu sort en 404, pas en 500", %{conn: conn} do
    # Un profil inexistant est un cas normal : une 500 polluerait le suivi
    # d'erreurs et afficherait une page de panne.
    assert_error_sent 404, fn -> live(conn, ~p"/u/personne_ici") end
  end

  test "propose la modification sur son propre profil", %{conn: conn, user: user} do
    {:ok, _lv, html} = conn |> log_in_user(user) |> live(~p"/u/cinephile")

    assert html =~ "Modifier mon profil"
  end

  test "ne propose pas la modification sur le profil d'un autre", %{conn: conn} do
    {:ok, _lv, html} = conn |> log_in_user(user_fixture()) |> live(~p"/u/cinephile")

    refute html =~ "Modifier mon profil"
  end

  test "l'avatar du bandeau mene au profil", %{conn: conn, user: user} do
    {:ok, _lv, html} = conn |> log_in_user(user) |> live(~p"/")

    assert html =~ ~s(href="/u/cinephile")
  end
end
