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

  describe "visibilite" do
    test "un profil prive masque la bio et le lieu", %{conn: conn, user: user} do
      {:ok, _user} =
        Accounts.update_user_visibility(Scope.for_user(user), user, %{
          "profile_visibility" => "private"
        })

      {:ok, _lv, html} = live(conn, ~p"/u/cinephile")

      assert html =~ "Ce profil est prive."
      refute html =~ "cinema japonais contemplatif"
      refute html =~ "Montpellier"
    end

    test "le nom et l'identifiant restent visibles sur un profil prive", %{
      conn: conn,
      user: user
    } do
      # Un profil prive n'est pas un profil inexistant : l'adresse publique
      # doit continuer a designer quelqu'un.
      {:ok, _user} =
        Accounts.update_user_visibility(Scope.for_user(user), user, %{
          "profile_visibility" => "private"
        })

      {:ok, _lv, html} = live(conn, ~p"/u/cinephile")

      assert html =~ "Cinephile"
      assert html =~ "@cinephile"
    end

    test "le proprietaire voit son profil prive en entier", %{conn: conn, user: user} do
      {:ok, user} =
        Accounts.update_user_visibility(Scope.for_user(user), user, %{
          "profile_visibility" => "private"
        })

      {:ok, _lv, html} = conn |> log_in_user(user) |> live(~p"/u/cinephile")

      assert html =~ "cinema japonais contemplatif"
      refute html =~ "Ce profil est prive."
    end
  end
end
