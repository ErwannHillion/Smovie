defmodule SmovieWeb.MessagingLiveTest do
  use SmovieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Smovie.AccountsFixtures

  alias Smovie.Accounts.Scope
  alias Smovie.Messaging
  alias Smovie.Repo

  setup %{conn: conn} do
    moi = user_fixture()
    autre = user_fixture()
    scope = Scope.for_user(moi)
    {:ok, conversation} = Messaging.find_or_create_direct(scope, autre)
    conversation = Repo.preload(conversation, members: :user)

    %{
      conn: log_in_user(conn, moi),
      moi: moi,
      autre: autre,
      scope: scope,
      autre_scope: Scope.for_user(autre),
      conversation: conversation
    }
  end

  test "liste les conversations", %{conn: conn, autre: autre} do
    {:ok, _lv, html} = live(conn, ~p"/messages")

    assert html =~ autre.display_name
    assert html =~ "Conversation privee"
  end

  test "affiche le badge de non-lus", %{
    conn: conn,
    autre_scope: autre_scope,
    conversation: conversation
  } do
    Messaging.send_message(autre_scope, conversation, %{"body" => "Coucou"})

    {:ok, _lv, html} = live(conn, ~p"/messages")

    assert html =~ "1"
  end

  test "ouvre un fil et envoie un message", %{
    conn: conn,
    conversation: conversation,
    scope: scope
  } do
    {:ok, lv, _html} = live(conn, ~p"/messages/#{conversation.id}")

    lv |> form("#composer", %{"message" => %{"body" => "Salut"}}) |> render_submit()

    assert render(lv) =~ "Salut"
    assert [%{body: "Salut"}] = Messaging.list_messages(conversation)
    assert Messaging.unread_count(scope) == 0
  end

  test "un message recu arrive sans rechargement", %{
    conn: conn,
    conversation: conversation,
    autre_scope: autre_scope
  } do
    {:ok, lv, _html} = live(conn, ~p"/messages/#{conversation.id}")

    Messaging.send_message(autre_scope, conversation, %{"body" => "Message entrant"})

    assert render(lv) =~ "Message entrant"
  end

  test "supprimer un message laisse une bulle", %{
    conn: conn,
    conversation: conversation,
    scope: scope
  } do
    {:ok, message} = Messaging.send_message(scope, conversation, %{"body" => "A effacer"})
    {:ok, lv, _html} = live(conn, ~p"/messages/#{conversation.id}")

    html = lv |> element(~s(button[phx-value-id="#{message.id}"])) |> render_click()

    assert html =~ "Message supprime"
    refute html =~ "A effacer"
  end

  test "une conversation d'autrui sort en 404", %{conversation: conversation} do
    # Repondre « existe mais vous n'en etes pas » confirmerait son existence a
    # qui tente des identifiants au hasard.
    tiers = user_fixture()

    assert_error_sent 404, fn ->
      build_conn() |> log_in_user(tiers) |> live(~p"/messages/#{conversation.id}")
    end
  end

  test "un identifiant illisible sort en 404", %{conn: conn} do
    assert_error_sent 404, fn -> live(conn, "/messages/abc") end
  end

  test "ouvrir un fil eteint ses non-lus", %{
    conn: conn,
    scope: scope,
    autre_scope: autre_scope,
    conversation: conversation
  } do
    Messaging.send_message(autre_scope, conversation, %{"body" => "Coucou"})
    assert Messaging.unread_count(scope) == 1

    {:ok, _lv, _html} = live(conn, ~p"/messages/#{conversation.id}")

    assert Messaging.unread_count(scope) == 0
  end
end
