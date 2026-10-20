defmodule SmovieWeb.Plugs.LocaleTest do
  use SmovieWeb.ConnCase, async: false

  alias Smovie.Accounts
  alias Smovie.Accounts.Scope

  describe "resolution de la locale" do
    test "retombe sur le francais sans aucun indice", %{conn: conn} do
      conn = get(conn, ~p"/")

      assert conn.assigns.locale == "fr"
      assert get_session(conn, :locale) == "fr"
    end

    test "suit l'en-tete accept-language du navigateur", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept-language", "en-US,en;q=0.9")
        |> get(~p"/")

      assert conn.assigns.locale == "en"
    end

    test "ignore la region et les poids de l'en-tete", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept-language", "en-GB;q=0.8,fr;q=0.2")
        |> get(~p"/")

      assert conn.assigns.locale == "en"
    end

    test "ignore une langue que l'application ne sert pas", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept-language", "de-DE,de;q=0.9,en;q=0.5")
        |> get(~p"/")

      assert conn.assigns.locale == "en"
    end

    test "le cookie prime sur l'en-tete", %{conn: conn} do
      conn =
        conn
        |> put_req_cookie("locale", "en")
        |> put_req_header("accept-language", "fr-FR,fr;q=0.9")
        |> get(~p"/")

      assert conn.assigns.locale == "en"
    end

    test "la preference du compte prime sur le cookie et sur l'en-tete", %{conn: conn} do
      user = Smovie.AccountsFixtures.user_fixture()
      {:ok, user} = Accounts.update_user_locale(user, "en")

      conn =
        conn
        |> log_in_user(user)
        |> put_req_cookie("locale", "fr")
        |> put_req_header("accept-language", "fr-FR")
        |> get(~p"/")

      assert conn.assigns.locale == "en"
      assert Scope.for_user(user).user.locale == "en"
    end

    test "un compte sans preference suit le navigateur", %{conn: conn} do
      user = Smovie.AccountsFixtures.user_fixture()

      conn =
        conn
        |> log_in_user(user)
        |> put_req_header("accept-language", "en")
        |> get(~p"/")

      assert user.locale == nil
      assert conn.assigns.locale == "en"
    end
  end

  describe "rendu" do
    test "les libelles sont en francais par defaut", %{conn: conn} do
      assert html_response(get(conn, ~p"/"), 200) =~ "Connexion"
    end

    test "les libelles passent en anglais avec le cookie", %{conn: conn} do
      html =
        conn
        |> put_req_cookie("locale", "en")
        |> get(~p"/")
        |> html_response(200)

      assert html =~ "Log in"
      assert html =~ "Sign up"
    end
  end

  describe "changement de langue" do
    test "pose le cookie et revient sur la page d'origine", %{conn: conn} do
      conn = put(conn, ~p"/locale/en", %{"return_to" => "/users/log-in"})

      assert redirected_to(conn) == "/users/log-in"
      assert conn.resp_cookies["locale"].value == "en"
    end

    test "enregistre la preference sur le compte connecte", %{conn: conn} do
      user = Smovie.AccountsFixtures.user_fixture()

      conn
      |> log_in_user(user)
      |> put(~p"/locale/en", %{"return_to" => "/"})

      assert Accounts.get_user!(user.id).locale == "en"
    end

    test "refuse une langue non servie", %{conn: conn} do
      conn = put(conn, ~p"/locale/de", %{"return_to" => "/"})

      assert redirected_to(conn) == "/"
      refute Map.has_key?(conn.resp_cookies, "locale")
    end

    test "ne redirige que vers un chemin interne", %{conn: conn} do
      conn = put(conn, ~p"/locale/en", %{"return_to" => "https://exemple.test/phishing"})

      assert redirected_to(conn) == "/"
    end
  end
end
