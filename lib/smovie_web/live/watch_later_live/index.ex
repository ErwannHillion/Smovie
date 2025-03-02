defmodule SmovieWeb.WatchLaterLive.Index do
  use SmovieWeb, :live_view

  alias Smovie.Movies
  alias Smovie.Movies.WatchLater

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :watchelater, Movies.list_watchelater())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Watch later")
    |> assign(:watch_later, Movies.get_watch_later!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Watch later")
    |> assign(:watch_later, %WatchLater{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Watchelater")
    |> assign(:watch_later, nil)
  end

  @impl true
  def handle_info({SmovieWeb.WatchLaterLive.FormComponent, {:saved, watch_later}}, socket) do
    {:noreply, stream_insert(socket, :watchelater, watch_later)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    watch_later = Movies.get_watch_later!(id)
    {:ok, _} = Movies.delete_watch_later(watch_later)

    {:noreply, stream_delete(socket, :watchelater, watch_later)}
  end
end
