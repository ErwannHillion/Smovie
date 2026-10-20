defmodule SmovieWeb.Hooks.Unread do
  @moduledoc """
  Expose le nombre de notifications non lues a toutes les LiveViews.

  Abonne a la boite du membre : le badge se met a jour sans rechargement,
  meme quand on est sur une fiche film.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [attach_hook: 4, connected?: 1]

  alias Smovie.Messaging
  alias Smovie.Social

  def on_mount(:default, _params, _session, socket) do
    scope = socket.assigns[:current_scope]
    socket = assign_counts(socket, scope)

    if connected?(socket), do: subscribe(socket, scope)

    {:cont, attach_hook(socket, :unread, :handle_info, &refresh/2)}
  end

  defp subscribe(_socket, nil), do: :ok

  defp subscribe(socket, scope) do
    Phoenix.PubSub.subscribe(Smovie.PubSub, Social.inbox_topic(scope.user.id))
    SmovieWeb.Presence.track_online(self(), scope.user)
    socket
  end

  defp refresh(:unread_changed, socket) do
    {:halt, assign_counts(socket, socket.assigns[:current_scope])}
  end

  defp refresh(_message, socket), do: {:cont, socket}

  defp assign_counts(socket, scope) do
    socket
    |> assign(:unread_count, Social.unread_count(scope))
    |> assign(:unread_messages, Messaging.unread_count(scope))
  end
end
