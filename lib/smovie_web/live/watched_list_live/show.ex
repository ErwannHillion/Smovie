defmodule SmovieWeb.WatchedListLive.Show do
  use SmovieWeb, :live_view

  alias Smovie.Movies

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:watched_list, Movies.get_watched_list!(id))}
  end

  defp page_title(:show), do: "Show Watched list"
  defp page_title(:edit), do: "Edit Watched list"
end
