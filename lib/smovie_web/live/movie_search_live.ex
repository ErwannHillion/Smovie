defmodule SmovieWeb.MovieSearchLive do
  use Phoenix.LiveView
  alias Smovie.TMDB
  alias Smovie.Repo
  alias Smovie.Movies.WatchedList
  alias Phoenix.HTML
  alias Smovie.Movies.WatchLater
  alias Phoenix.LiveView.JS

  import SmovieWeb.CoreComponents

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    {:ok,
     assign(socket,
       query: "",
       results: [],
       selected_movie: nil,
       current_user: current_user,
       show_modal: false
     )}
  end

  def handle_event("search", %{"query" => query}, socket) do
    case TMDB.search_movie(query) do
      {:ok, %{"results" => results}} ->
        {:noreply, assign(socket, results: results, query: query)}

      {:error, _reason} ->
        {:noreply, assign(socket, results: [], query: query)}
    end
  end

  def handle_event("update_query", %{"query" => query}, socket) do
    case TMDB.search_movie(query) do
      {:ok, %{"results" => results}} ->
        {:noreply, assign(socket, results: results, query: query)}

      {:error, _reason} ->
        {:noreply, assign(socket, results: [], query: query)}
    end
  end

  def handle_event("open_modal", %{"movie_id" => movie_id, "modal_type" => modal_type}, socket) do
    selected_movie =
      Enum.find(socket.assigns.results, fn m -> m["id"] == String.to_integer(movie_id) end)

    {:noreply,
     assign(socket, selected_movie: selected_movie, show_modal: true, modal_type: modal_type)}
  end

  def handle_event(
        "save_to_watchlist",
        %{"urating" => urating, "udescription" => udescription, "uwatcheddate" => uwatcheddate},
        socket
      ) do
    user_id = socket.assigns.current_user.id
    movie_id = socket.assigns.selected_movie["id"]

    # Vérifie si le film existe déjà dans la watchlist
    existing_entry =
      Repo.get_by(WatchedList, user_id: user_id, id_movie: movie_id)

    if existing_entry do
      {:noreply,
       assign(socket,
         show_modal: true,
         modal_message: "Ce film est déjà dans votre watchlist.",
         modal_type: "error"
       )}
    else
      urating =
        urating
        |> String.trim()
        |> (fn x -> if String.contains?(x, "."), do: x, else: x <> ".0" end).()
        |> String.to_float()

      watched_list = %WatchedList{
        urating: urating,
        udescription: udescription,
        uwatcheddate: Date.from_iso8601!(uwatcheddate),
        user_id: user_id,
        id_movie: movie_id
      }

      case Repo.insert(watched_list) do
        {:ok, _record} ->
          {:noreply, assign(socket, show_modal: false, selected_movie: nil, modal_type: nil)}

        {:error, changeset} ->
          IO.inspect(changeset, label: "Failed to Insert Watched List")

          {:noreply,
           assign(socket,
             show_modal: true,
             selected_movie: socket.assigns.selected_movie,
             modal_type: "watchlist"
           )}
      end
    end
  end

  def handle_event("add_to_watch_later", %{"movie_id" => movie_id}, socket) do
    movie =
      Enum.find(socket.assigns.results, fn m -> m["id"] == String.to_integer(movie_id) end)

    if movie do
      existing_entry =
        Repo.get_by(WatchLater, user_id: socket.assigns.current_user.id, id_movie: movie["id"])

      if existing_entry do
        {:noreply,
         assign(socket,
           show_modal: true,
           modal_message: "Film déjà dans la liste à regarder plus tard",
           modal_type: "watch_later"
         )}
      else
        watch_later = %WatchLater{
          id_movie: movie["id"],
          movie_title: movie["title"],
          movie_description: movie["overview"],
          user_id: socket.assigns.current_user.id
        }

        case Repo.insert(watch_later) do
          {:ok, _record} ->
            {:noreply,
             assign(socket,
               show_modal: true,
               modal_message: "Film ajouté avec succès",
               modal_type: "watch_later"
             )}

          {:error, changeset} ->
            IO.inspect(changeset, label: "Failed to Insert Watch Later")

            {:noreply,
             assign(socket,
               show_modal: true,
               modal_message: "Erreur lors de l'ajout du film",
               modal_type: "watch_later"
             )}
        end
      end
    else
      {:noreply,
       assign(socket,
         show_modal: true,
         modal_message: "Film non trouvé",
         modal_type: "watch_later"
       )}
    end
  end

  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, show_modal: false, selected_movie: nil, modal_type: nil)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <form phx-submit="search" phx-change="update_query">
        <input type="text" name="query" value={@query} placeholder="Rechercher un film..." />
        <button type="submit">Rechercher</button>
      </form>
      <ul>
        <%= for movie <- @results do %>
          <li>
            <img src={"https://image.tmdb.org/t/p/w500#{movie["poster_path"]}"} alt={movie["title"]} />
            {movie["title"]} ({movie["release_date"]})
            <p>{movie["vote_average"]}</p>
            <button
              phx-click="open_modal"
              phx-value-movie_id={movie["id"]}
              phx-value-modal_type="watchlist"
            >
              Ajouter à la watchlist
            </button>
            <button phx-click="add_to_watch_later" phx-value-movie_id={movie["id"]}>
              Ajouter à regarder plus tard
            </button>
          </li>
        <% end %>
      </ul>

      <%= if @show_modal do %>
        <.modal id="modal" show={@show_modal} on_cancel={JS.push("close_modal")}>
          <%= if @modal_type == "watchlist" do %>
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
          <% else %>
            <%= if @modal_type == "watch_later" do %>
              <h2 class="text-lg font-bold">
                Ajouter {@selected_movie["title"]} à regarder plus tard
              </h2>
              <p>{@modal_message}</p>
              <div class="flex justify-end space-x-2 mt-4">
                <button
                  type="button"
                  phx-click="close_modal"
                  class="bg-gray-500 text-white px-4 py-2 rounded"
                >
                  Fermer
                </button>
              </div>
            <% else %>
              <%= if @modal_type == "error" do %>
                <h2 class="text-lg font-bold">Erreur</h2>
                <p>{@modal_message}</p>
                <div class="flex justify-end space-x-2 mt-4">
                  <button
                    type="button"
                    phx-click="close_modal"
                    class="bg-gray-500 text-white px-4 py-2 rounded"
                  >
                    Fermer
                  </button>
                </div>
              <% end %>
            <% end %>
          <% end %>
        </.modal>
      <% end %>
    </div>
    """
  end
end
