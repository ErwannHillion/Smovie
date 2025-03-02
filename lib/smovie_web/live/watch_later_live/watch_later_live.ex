defmodule SmovieWeb.WatchLaterLive do
  use Phoenix.LiveView
  alias Smovie.Movies
  alias Smovie.TMDB

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

  def render(assigns) do
    ~H"""
    <div>
      <h1>Ma Liste de Films à Regarder Plus Tard</h1>
      <table>
        <thead>
          <tr>
            <th>Image</th>
            <th>Titre</th>
            <th>Description</th>
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
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end
end
