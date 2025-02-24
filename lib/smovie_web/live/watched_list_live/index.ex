defmodule SmovieWeb.WatchedListLive.Index do
  use SmovieWeb, :live_view

  alias Smovie.Movies
  alias Smovie.Movies.WatchedList

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :watchedlist, Movies.list_watchedlist())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Watched list")
    |> assign(:watched_list, Movies.get_watched_list!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Watched list")
    |> assign(:watched_list, %WatchedList{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Watchedlist")
    |> assign(:watched_list, nil)
  end

  @impl true
  def handle_info({SmovieWeb.WatchedListLive.FormComponent, {:saved, watched_list}}, socket) do
    {:noreply, stream_insert(socket, :watchedlist, watched_list)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    watched_list = Movies.get_watched_list!(id)
    {:ok, _} = Movies.delete_watched_list(watched_list)

    {:noreply, stream_delete(socket, :watchedlist, watched_list)}
  end
end
