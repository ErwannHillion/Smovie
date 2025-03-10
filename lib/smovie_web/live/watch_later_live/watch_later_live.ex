defmodule SmovieWeb.WatchLaterLive do
  use Phoenix.LiveView, layout: {SmovieWeb.Layouts, :app}

  alias Smovie.Movies
  alias Smovie.TMDB

  import SaladUI.Button
  import SaladUI.Table

  def mount(_params, _session, %{assigns: %{current_user: current_user}} = socket) do
    if connected?(socket), do: send(self(), :load_watch_later_list)
    {:ok, assign(socket, current_user: current_user, watch_later_list: [], movie_details: %{})}
  end

  def handle_info(:load_watch_later_list, socket) do
    watch_later_list = Movies.list_watch_later_for_user(socket.assigns.current_user.id)
    movie_details = fetch_movie_details(watch_later_list)
    {:noreply, assign(socket, watch_later_list: watch_later_list, movie_details: movie_details)}
  end

  defp fetch_movie_details(watch_later_list) do
    Enum.reduce(watch_later_list, %{}, fn entry, acc ->
      case TMDB.get_movie_details(entry.id_movie) do
        {:ok, details} -> Map.put(acc, entry.id_movie, details)
        {:error, _reason} -> acc
      end
    end)
  end

  def handle_event("delete", %{"id" => entry_id}, socket) do
    current_user_id = socket.assigns.current_user.id

    entry = Movies.get_watch_later!(entry_id)

    if entry.user_id == current_user_id do
      Movies.delete_watch_later(entry)

      watch_later_list = Movies.list_watch_later_for_user(current_user_id)
      movie_details = fetch_movie_details(watch_later_list)

      {:noreply, assign(socket, watch_later_list: watch_later_list, movie_details: movie_details)}
    else
      {:noreply, put_flash(socket, :error, "Vous n'êtes pas autorisé à supprimer ce film.")}
    end
  end

  def render(assigns) do
    ~H"""
    <div>
      <h1>Ma Liste de Films à Regarder Plus Tard</h1>
      <%= if @flash[:error] do %>
        <div class="alert alert-danger">
          {@flash[:error]}
        </div>
      <% end %>
      <table>
        <thead>
          <tr>
            <th>Image</th>
            <th>Titre</th>
            <th>Description</th>
            <th>Action</th>
          </tr>
        </thead>
        <tbody>
          <%= for entry <- @watch_later_list do %>
            <tr>
              <td>
                <%= if details = @movie_details[entry.id_movie] do %>
                  <img
                    src={"https://image.tmdb.org/t/p/w500#{details["poster_path"]}"}
                    alt={details["title"]}
                    class="h-9 w-9"
                  />
                <% end %>
              </td>
              <td>
                <%= if details = @movie_details[entry.id_movie] do %>
                  {details["title"]}
                <% end %>
              </td>
              <td>{entry.movie_description}</td>
              <td>
                <.button
                  phx-click="delete"
                  phx-value-id={entry.id}
                  class="rounded-full bg-red-500 hover:bg-red-600"
                >
                  Supprimer
                </.button>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end
end
