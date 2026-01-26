defmodule SmovieWeb.WatchlistLive do
  use SmovieWeb, :live_view

  alias Smovie.Movies

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-100">
      <%!-- Header --%>
      <div class="bg-primary shadow-lg">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between py-4">
            <div class="flex items-center">
              <.link navigate={~p"/"} class="text-2xl font-bold text-primary-content">
                SMovie
              </.link>
              <.icon name="hero-chevron-right" class="w-5 h-5 text-primary-content mx-2" />
              <span class="text-lg text-primary-content">À regarder</span>
            </div>
            
            <div class="flex items-center space-x-4">
              <.link navigate={~p"/my-movies"} class="btn btn-ghost text-primary-content">
                Mes films
              </.link>
              <.link navigate={~p"/users"} class="btn btn-ghost text-primary-content">
                Membres
              </.link>
              <.link navigate={~p"/"} class="btn btn-ghost text-primary-content">
                Accueil
              </.link>
            </div>
          </div>
        </div>
      </div>

      <%!-- Contenu principal --%>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="mb-6">
          <h1 class="text-3xl font-bold mb-2">Films à regarder</h1>
          <p class="text-base-content/70">
            <%= length(@watchlist_movies) %> film<%= if length(@watchlist_movies) > 1, do: "s" %> dans votre liste
          </p>
        </div>

        <%= if @watchlist_movies == [] do %>
          <div class="text-center py-16">
            <.icon name="hero-bookmark" class="w-16 h-16 text-base-content/20 mx-auto mb-4" />
            <h2 class="text-xl font-semibold mb-2">Votre liste est vide</h2>
            <p class="text-base-content/70 mb-4">
              Ajoutez des films à votre liste pour les regarder plus tard
            </p>
            <.link navigate={~p"/"} class="btn btn-primary">
              Découvrir des films
            </.link>
          </div>
        <% else %>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <%= for {user_movie, movie} <- @watchlist_movies do %>
              <div class="card bg-base-100 shadow-xl">
                <figure class="relative h-64">
                  <%= if movie.poster_path do %>
                    <img
                      src={"https://image.tmdb.org/t/p/w500#{movie.poster_path}"}
                      alt={movie.title}
                      class="w-full h-full object-cover"
                    />
                  <% else %>
                    <div class="w-full h-full bg-base-200 flex items-center justify-center">
                      <.icon name="hero-photo" class="w-16 h-16 text-base-content/20" />
                    </div>
                  <% end %>
                  
                  <%!-- Actions overlay --%>
                  <div class="absolute top-2 right-2 flex space-x-1">
                    <button
                      phx-click="mark_as_watched"
                      phx-value-movie_id={movie.id}
                      class="btn btn-sm btn-circle btn-success opacity-80 hover:opacity-100"
                      title="Marquer comme vu"
                    >
                      <.icon name="hero-eye" class="w-4 h-4" />
                    </button>
                    <button
                      phx-click="remove_from_watchlist"
                      phx-value-movie_id={movie.id}
                      class="btn btn-sm btn-circle btn-error opacity-80 hover:opacity-100"
                      title="Retirer de la liste"
                    >
                      <.icon name="hero-trash" class="w-4 h-4" />
                    </button>
                  </div>
                </figure>
                
                <div class="card-body p-4">
                  <h3 class="card-title text-lg font-bold leading-tight">
                    <%= movie.title %>
                  </h3>
                  
                  <div class="flex items-center justify-between text-sm text-base-content/70 mb-4">
                    <span>
                      <%= if movie.release_date do %>
                        <%= movie.release_date.year %>
                      <% end %>
                    </span>
                    <div class="flex items-center">
                      <.icon name="hero-star" class="w-3 h-3 text-yellow-400 mr-1" />
                      <span><%= if movie.vote_average, do: Float.round(movie.vote_average, 1), else: "N/A" %></span>
                    </div>
                  </div>
                  
                  <%= if movie.overview do %>
                    <p class="text-sm text-base-content/70 line-clamp-3">
                      <%= movie.overview %>
                    </p>
                  <% end %>
                  
                  <div class="flex items-center justify-between text-xs text-base-content/60 mt-4">
                    <span>
                      Ajouté le <%= Calendar.strftime(user_movie.inserted_at, "%d/%m/%Y") %>
                    </span>
                    <%= if movie.genres && movie.genres != [] do %>
                      <div class="flex flex-wrap gap-1">
                        <%= for genre <- Enum.take(movie.genres, 2) do %>
                          <span class="badge badge-outline badge-xs">
                            <%= genre %>
                          </span>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                  
                  <%!-- Actions --%>
                  <div class="card-actions justify-end mt-4">
                    <button
                      phx-click="mark_as_watched"
                      phx-value-movie_id={movie.id}
                      class="btn btn-sm btn-success"
                    >
                      <.icon name="hero-eye" class="w-4 h-4 mr-1" />
                      Marquer comme vu
                    </button>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
          
          <%!-- Pagination --%>
          <div class="flex justify-center mt-8">
            <%= if @loading do %>
              <span class="loading loading-spinner loading-md"></span>
            <% else %>
              <button
                phx-click="load_more"
                class="btn btn-outline"
              >
                Charger plus
              </button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    if socket.assigns.current_scope && socket.assigns.current_scope.user do
      user_id = socket.assigns.current_scope.user.id
      
      socket =
        socket
        |> assign(:user_id, user_id)
        |> assign(:watchlist_movies, [])
        |> assign(:page, 1)
        |> assign(:loading, false)
        |> load_watchlist_movies()

      {:ok, socket}
    else
      {:ok, redirect(socket, to: ~p"/users/log-in")}
    end
  end

  def handle_event("load_more", _params, socket) do
    new_page = socket.assigns.page + 1
    
    socket =
      socket
      |> assign(:page, new_page)
      |> assign(:loading, true)
      |> load_more_movies(new_page)

    {:noreply, socket}
  end

  def handle_event("mark_as_watched", %{"movie_id" => movie_id}, socket) do
    user_id = socket.assigns.user_id
    movie_id = String.to_integer(movie_id)
    
    case Movies.mark_as_watched(user_id, movie_id) do
      {:ok, _user_movie} ->
        socket =
          socket
          |> put_flash(:info, "Film marqué comme vu")
          |> reload_watchlist_movies()

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Erreur lors du marquage du film")}
    end
  end

  def handle_event("remove_from_watchlist", %{"movie_id" => movie_id}, socket) do
    user_id = socket.assigns.user_id
    movie_id = String.to_integer(movie_id)
    
    case Movies.get_user_movie(user_id, movie_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Film non trouvé")}

      user_movie ->
        case Movies.delete_user_movie(user_movie) do
          {:ok, _} ->
            socket =
              socket
              |> put_flash(:info, "Film retiré de votre liste")
              |> reload_watchlist_movies()

            {:noreply, socket}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Erreur lors de la suppression")}
        end
    end
  end

  defp load_watchlist_movies(socket) do
    watchlist_movies = Movies.get_watchlist_movies(socket.assigns.user_id, limit: 20)
    assign(socket, :watchlist_movies, watchlist_movies)
  end

  defp load_more_movies(socket, page) do
    offset = (page - 1) * 20
    new_movies = Movies.get_watchlist_movies(socket.assigns.user_id, limit: 20, offset: offset)
    current_movies = socket.assigns.watchlist_movies

    socket
    |> assign(:watchlist_movies, current_movies ++ new_movies)
    |> assign(:loading, false)
  end

  defp reload_watchlist_movies(socket) do
    watchlist_movies = Movies.get_watchlist_movies(socket.assigns.user_id, limit: socket.assigns.page * 20)
    assign(socket, :watchlist_movies, watchlist_movies)
  end
end
