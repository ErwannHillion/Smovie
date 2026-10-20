defmodule SmovieWeb.MessagingLive.PresenceTest do
  use SmovieWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Smovie.AccountsFixtures

  alias Smovie.Accounts.Scope
  alias Smovie.Messaging
  alias Smovie.Repo
  alias SmovieWeb.Presence

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
      autre_scope: Scope.for_user(autre),
      conversation: Repo.preload(conversation, members: :user)
    }
  end

  test "le badge de messages apparait sur la barre basse", %{
    conn: conn,
    autre_scope: autre_scope,
    conversation: conversation
  } do
    Messaging.send_message(autre_scope, conversation, %{"body" => "Coucou"})

    {:ok, lv, _html} = live(conn, ~p"/")

    assert lv |> element(~s([data-role="messages-badge"])) |> render() =~ "1"
  end

  test "le badge disparait une fois le fil ouvert", %{
    conn: conn,
    autre_scope: autre_scope,
    conversation: conversation
  } do
    Messaging.send_message(autre_scope, conversation, %{"body" => "Coucou"})
    {:ok, _lv, _html} = live(conn, ~p"/messages/#{conversation.id}")

    {:ok, accueil, _html} = live(conn, ~p"/")

    refute has_element?(accueil, ~s([data-role="messages-badge"]))
  end

  test "la frappe s'annonce aux autres membres", %{
    conn: conn,
    moi: moi,
    autre: autre,
    conversation: conversation
  } do
    {:ok, lv, _html} = live(conn, ~p"/messages/#{conversation.id}")

    # On simule l'autre membre depuis un processus distinct.
    parent = self()

    spawn_link(fn ->
      Presence.track_conversation(self(), conversation.id, autre)
      Presence.set_typing(self(), conversation.id, autre, true)
      send(parent, :tracked)
      Process.sleep(300)
    end)

    assert_receive :tracked

    assert Presence.typing_names(conversation.id, moi) == [autre.display_name]

    lv |> render()
  end

  test "typing_names/2 ignore sa propre frappe", %{moi: moi, conversation: conversation} do
    Presence.track_conversation(self(), conversation.id, moi)
    Presence.set_typing(self(), conversation.id, moi, true)

    assert Presence.typing_names(conversation.id, moi) == []
  end

  test "online?/1 suit les connexions", %{conn: conn, moi: moi} do
    refute Presence.online?(moi.id)

    {:ok, _lv, _html} = live(conn, ~p"/")

    assert Presence.online?(moi.id)
  end
end
