defmodule SmovieWeb.Hooks.Unread do
  @moduledoc """
  Expose le nombre de notifications non lues a toutes les LiveViews.

  Abonne a la boite du membre : le badge se met a jour sans rechargement,
  meme quand on est sur une fiche film.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [attach_hook: 4, connected?: 1]

  alias Smovie.Social

  def on_mount(:default, _params, _session, socket) do
    socket = assign(socket, :unread_count, Social.unread_count(socket.assigns[:current_scope]))

    if connected?(socket), do: subscribe(socket.assigns[:current_scope])

    {:cont, attach_hook(socket, :unread, :handle_info, &refresh/2)}
  end

  defp subscribe(nil), do: :ok

  defp subscribe(scope) do
    Phoenix.PubSub.subscribe(Smovie.PubSub, Social.inbox_topic(scope.user.id))
  end

  defp refresh(:unread_changed, socket) do
    {:halt, assign(socket, :unread_count, Social.unread_count(socket.assigns[:current_scope]))}
  end

  defp refresh(_message, socket), do: {:cont, socket}
end
