defmodule SmovieWeb.MessagingLive.ShareTest do
  use SmovieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Smovie.AccountsFixtures
  import Smovie.CatalogFixtures

  alias Smovie.Accounts.Scope
  alias Smovie.Messaging
  alias Smovie.Repo
  alias Smovie.Social

  setup %{conn: conn} do
    moi = user_fixture()
    autre = user_fixture()
    scope = Scope.for_user(moi)
    {:ok, conversation} = Messaging.find_or_create_direct(scope, autre)

    %{
      conn: log_in_user(conn, moi),
      moi: moi,
      autre: autre,
      scope: scope,
      conversation: Repo.preload(conversation, members: :user),
      movie: movie_fixture()
    }
  end

  describe "partage depuis une fiche" do
    test "envoie une carte film", %{conn: conn, movie: movie, conversation: conversation} do
      {:ok, lv, _html} = live(conn, ~p"/film/#{movie.slug}")

      lv |> element(~s(button[phx-click="open_share"])) |> render_click()
      lv |> element(~s(button[phx-value-id="#{conversation.id}"])) |> render_click()
      lv |> element(~s(button[phx-click="confirm_share"])) |> render_click()

      assert [%{kind: :work_share, shared_work_id: id}] = Messaging.list_messages(conversation)
      assert id == movie.id
    end

    test "la carte n'affiche pas de lien mort si l'oeuvre disparait", %{
      conn: conn,
      movie: movie,
      conversation: conversation
    } do
      # Le partage ne copie rien : il porte une reference, donc une oeuvre
      # supprimee degrade la carte proprement.
      {:ok, lv, _html} = live(conn, ~p"/film/#{movie.slug}")
      lv |> element(~s(button[phx-click="open_share"])) |> render_click()
      lv |> element(~s(button[phx-value-id="#{conversation.id}"])) |> render_click()
      lv |> element(~s(button[phx-click="confirm_share"])) |> render_click()

      Repo.delete!(movie)

      {:ok, _lv, html} = live(conn, ~p"/messages/#{conversation.id}")

      assert html =~ "Contenu partage indisponible"
    end

    test "un visiteur est renvoye vers la connexion", %{movie: movie} do
      {:ok, lv, _html} = live(build_conn(), ~p"/film/#{movie.slug}")

      assert {:error, {:live_redirect, %{to: "/users/log-in"}}} =
               lv |> element(~s(button[phx-click="open_share"])) |> render_click()
    end
  end

  describe "creation de groupe" do
    test "cree un groupe avec les comptes suivis", %{conn: conn, scope: scope, autre: autre} do
      Social.follow(scope, autre)

      {:ok, lv, _html} = live(conn, ~p"/messages/nouveau")

      lv |> element(~s(button[phx-value-user-id="#{autre.id}"])) |> render_click()

      assert {:error, {:live_redirect, %{to: path}}} =
               lv
               |> form("#group_form", %{"group" => %{"title" => "Les Cinevores"}})
               |> render_submit()

      assert path =~ "/messages/"
    end

    test "ne propose que les comptes suivis", %{conn: conn, autre: autre} do
      # Proposer tout l'annuaire transformerait la page en outil de
      # demarchage.
      {:ok, _lv, html} = live(conn, ~p"/messages/nouveau")

      refute html =~ ~s(phx-value-user-id="#{autre.id}")
      assert html =~ "Suivez d" and html =~ "quelques membres"
    end

    test "refuse un nom vide", %{conn: conn, scope: scope, autre: autre} do
      Social.follow(scope, autre)
      {:ok, lv, _html} = live(conn, ~p"/messages/nouveau")

      html = lv |> form("#group_form", %{"group" => %{"title" => "  "}}) |> render_submit()

      assert html =~ "Donnez un nom"
    end
  end
end
