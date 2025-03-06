defmodule SmovieWeb.WatchLaterLive.Show do
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
     |> assign(:watch_later, Movies.get_watch_later!(id))}
  end

  defp page_title(:show), do: "Show Watch later"
  defp page_title(:edit), do: "Edit Watch later"
end
