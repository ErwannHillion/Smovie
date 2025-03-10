defmodule SmovieWeb.HomeLive do
  use SmovieWeb, :live_view

  alias Smovie.TMDB
  alias Smovie.Repo
  alias Smovie.Movies.WatchedList
  alias Smovie.Movies.WatchLater

  import SaladUI.Card

  def mount(_params, _session, socket) do
    current_user = Map.get(socket.assigns, :current_user, nil)

    if connected?(socket), do: send(self(), :load_latest_movies)

    {:ok,
     assign(socket,
       latest_movies: [],
       current_user: current_user,
       show_modal: false,
       modal_type: nil,
       selected_movie: nil,
       modal_message: nil
     )}
  end

  # Load the latest movies from the TMDB API
  def handle_info(:load_latest_movies, socket) do
    case TMDB.get_latest_movies() do
      {:ok, %{"results" => results}} ->
        {:noreply, assign(socket, latest_movies: results)}

      {:error, _reason} ->
        {:noreply, assign(socket, latest_movies: [])}
    end
  end

  # Open modal with the selected movie and modal type
  def handle_event("open_modal", %{"movie_id" => movie_id, "modal_type" => modal_type}, socket) do
    selected_movie =
      Enum.find(socket.assigns.latest_movies, fn m -> m["id"] == String.to_integer(movie_id) end)

    {:noreply,
     assign(socket, selected_movie: selected_movie, show_modal: true, modal_type: modal_type)}
  end

  # Close modal
  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, show_modal: false, selected_movie: nil, modal_type: nil)}
  end

  # Add the movie to the watched list
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

  # Add the movie to the watch later list
  def handle_event("add_to_watch_later", %{"movie_id" => movie_id}, socket) do
    user_id = socket.assigns.current_user.id
    movie_id = String.to_integer(movie_id)

    movie =
      Enum.find(socket.assigns.latest_movies, fn m -> m["id"] == movie_id end)

    if movie do
      existing_entry =
        Repo.get_by(WatchLater, user_id: user_id, id_movie: movie_id)

      if existing_entry do
        {:noreply,
         assign(socket,
           show_modal: true,
           modal_message: "Ce film est déjà dans votre liste à regarder plus tard.",
           modal_type: "error"
         )}
      else
        watch_later = %WatchLater{
          id_movie: movie["id"],
          movie_title: movie["title"],
          movie_description: movie["overview"],
          user_id: user_id
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

  # Render function using HEEx
  def render(assigns) do
    ~H"""
    <div>
      <h1>Derniers Films Sortis</h1>
      <ul>
        <div class="grid grid-cols-4 gap-4">
          <%= for movie <- @latest_movies do %>
            <.card class="bg-black text-white border-none">
              <.card_header>
                <.card_title class="mb-6">{movie["title"]}</.card_title>
                <.card_description class="min-h-[10rem] max-h-[20rem]">
                  {movie["overview"]}
                </.card_description>
              </.card_header>
              <.card_content>
                <p>Date de sortie : {movie["release_date"]}</p>
                <p>Note : {movie["vote_average"]}/10 ⭐️</p>
                <img
                  class="w100 mt-10"
                  src={"https://image.tmdb.org/t/p/w500#{movie["poster_path"]}"}
                  alt={movie["title"]}
                />
              </.card_content>
              <.card_footer class="flex justify-between">
                <.button
                  phx-click="open_modal"
                  phx-value-movie_id={movie["id"]}
                  phx-value-modal_type="watchlist"
                  class="px-2 py-1 text-xs text-black !bg-stone-300"
                >
                  Ajouter à la watchlist
                </.button>
                <.button
                  phx-click="add_to_watch_later"
                  phx-value-movie_id={movie["id"]}
                  class="px-2 py-1 text-xs text-black !bg-stone-300"
                >
                  Ajouter à regarder plus tard
                </.button>
              </.card_footer>
            </.card>
          <% end %>
        </div>
      </ul>

      <%= if @show_modal do %>
        <.dark_modal id="modal" show={@show_modal} on_cancel={JS.push("close_modal")}>
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
        </.dark_modal>
      <% end %>
    </div>
    """
  end
end
