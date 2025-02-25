defmodule SmovieWeb.WatchedListLive do
  use Phoenix.LiveView
  alias Smovie.Movies
  alias Smovie.TMDB

  def mount(_params, _session, %{assigns: %{current_user: current_user}} = socket) do
    if connected?(socket), do: send(self(), :load_watched_list)
    {:ok, assign(socket, current_user: current_user, watched_list: [], movie_details: %{})}
  end

  def handle_info(:load_watched_list, socket) do
    watched_list = Movies.list_watched_lists_for_user(socket.assigns.current_user.id)
    movie_details = fetch_movie_details(watched_list)
    {:noreply, assign(socket, watched_list: watched_list, movie_details: movie_details)}
  end

  # ici on fetch les films à partir de l'id du film
  defp fetch_movie_details(watched_list) do
    Enum.reduce(watched_list, %{}, fn entry, acc ->
      case TMDB.get_movie_details(entry.id_movie) do
        {:ok, details} -> Map.put(acc, entry.id_movie, details)
        {:error, _reason} -> acc
      end
    end)
  end

  def render(assigns) do
    ~H"""
    <div>
      <h1>Ma Liste de Films Regardés</h1>
      <table>
        <thead>
          <tr>
            <th>Image</th>
            <th>Titre</th>
            <th>Note</th>
            <th>Description</th>
            <th>Date de Visionnage</th>
          </tr>
        </thead>
        <tbody>
          <%= for entry <- @watched_list do %>
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
              <td>{entry.urating}</td>
              <td>{entry.udescription}</td>
              <td>{entry.uwatcheddate}</td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end
end
