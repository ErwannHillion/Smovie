defmodule SmovieWeb.HomeLive do
  use Phoenix.LiveView
  alias Smovie.TMDB
  alias Smovie.Repo
  alias Smovie.Movies.WatchedList

  def mount(_params, _session, socket) do
    current_user = Map.get(socket.assigns, :current_user, nil)

    if connected?(socket), do: send(self(), :load_latest_movies)

    {:ok, assign(socket, latest_movies: [], current_user: current_user, show_modal: false)}
  end

  def handle_info(:load_latest_movies, socket) do
    case TMDB.get_latest_movies() do
      {:ok, %{"results" => results}} ->
        {:noreply, assign(socket, latest_movies: results)}

      {:error, _reason} ->
        {:noreply, assign(socket, latest_movies: [])}
    end
  end

  def handle_event("open_modal", %{"movie_id" => movie_id}, socket) do
    selected_movie =
      Enum.find(socket.assigns.latest_movies, fn m -> m["id"] == String.to_integer(movie_id) end)

    {:noreply, assign(socket, selected_movie: selected_movie, show_modal: true)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, show_modal: false, selected_movie: nil)}
  end

  def handle_event(
        "save_to_watchlist",
        %{"urating" => urating, "udescription" => udescription, "uwatcheddate" => uwatcheddate},
        socket
      ) do
    urating =
      urating
      |> String.trim()
      |> (fn x -> if String.contains?(x, "."), do: x, else: x <> ".0" end).()
      |> String.to_float()

    watched_list = %WatchedList{
      urating: urating,
      udescription: udescription,
      uwatcheddate: Date.from_iso8601!(uwatcheddate),
      user_id: socket.assigns.current_user.id,
      id_movie: socket.assigns.selected_movie["id"]
    }

    case Repo.insert(watched_list) do
      {:ok, _record} ->
        {:noreply, assign(socket, show_modal: false, selected_movie: nil)}

      {:error, changeset} ->
        IO.inspect(changeset, label: "Failed to Insert Watched List")

        {:noreply,
         assign(socket, show_modal: true, selected_movie: socket.assigns.selected_movie)}
    end
  end

  def render(assigns) do
    ~H"""
    <div>
      <h1>Derniers Films Sortis</h1>
      <ul>
        <%= for movie <- @latest_movies do %>
          <li>
            <img src={"https://image.tmdb.org/t/p/w500#{movie["poster_path"]}"} alt={movie["title"]} />
            <h2>{movie["title"]}</h2>
            <p>Date de sortie : {movie["release_date"]}</p>
            <p>Note : {movie["vote_average"]}</p>
            <%= if @current_user do %>
              <button phx-click="open_modal" phx-value-movie_id={movie["id"]}>
                Ajouter à la watchlist
              </button>
            <% end %>
          </li>
        <% end %>
      </ul>

      <%= if @show_modal do %>
        <div id="modal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center">
          <div class="bg-white p-6 rounded-lg shadow-lg w-1/3">
            <h2 class="text-lg font-bold">Ajouter {@selected_movie["title"]} à votre watchlist</h2>
            <form phx-submit="save_to_watchlist">
              <label>Note :</label>
              <input type="number" step="0.1" name="urating" required />
              <label>Description :</label>
              <textarea name="udescription"></textarea>
              <label>Date de visionnage :</label>
              <input type="date" name="uwatcheddate" required />
              <div class="flex justify-end space-x-2 mt-4">
                <button type="submit" class="bg-blue-500 text-white px-4 py-2 rounded">
                  Enregistrer
                </button>
                <button
                  type="button"
                  phx-click="close_modal"
                  class="bg-gray-500 text-white px-4 py-2 rounded"
                >
                  Annuler
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
