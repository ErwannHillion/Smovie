defmodule SmovieWeb.MyMoviesLive do
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
              <span class="text-lg text-primary-content">Mes films</span>
            </div>
            
            <div class="flex items-center space-x-4">
              <.link navigate={~p"/watchlist"} class="btn btn-ghost text-primary-content">
                À regarder
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
          <h1 class="text-3xl font-bold mb-2">Mes films vus</h1>
          <p class="text-base-content/70">
            <%= length(@watched_movies) %> film<%= if length(@watched_movies) > 1, do: "s" %> dans votre collection
          </p>
        </div>

        <%= if @watched_movies == [] do %>
          <div class="text-center py-16">
            <.icon name="hero-film" class="w-16 h-16 text-base-content/20 mx-auto mb-4" />
            <h2 class="text-xl font-semibold mb-2">Aucun film vu</h2>
            <p class="text-base-content/70 mb-4">
              Commencez à construire votre collection en marquant des films comme vus
            </p>
            <.link navigate={~p"/"} class="btn btn-primary">
              Découvrir des films
            </.link>
          </div>
        <% else %>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <%= for {user_movie, movie} <- @watched_movies do %>
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
                  
                  <%!-- Actions --%>
                  <div class="absolute top-2 right-2">
                    <div class="dropdown dropdown-end">
                      <div tabindex="0" role="button" class="btn btn-sm btn-circle btn-ghost bg-black/50 text-white">
                        <.icon name="hero-ellipsis-vertical" class="w-4 h-4" />
                      </div>
                      <ul tabindex="0" class="dropdown-content menu bg-base-100 rounded-box z-[1] w-52 p-2 shadow">
                        <li>
                          <button
                            phx-click="remove_movie"
                            phx-value-movie_id={movie.id}
                            class="text-error"
                          >
                            <.icon name="hero-trash" class="w-4 h-4" />
                            Retirer de ma liste
                          </button>
                        </li>
                      </ul>
                    </div>
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
                    <span>
                      <%= if user_movie.watched_at do %>
                        Vu le <%= Calendar.strftime(user_movie.watched_at, "%d/%m/%Y") %>
                      <% end %>
                    </span>
                  </div>
                  
                  <%!-- Rating --%>
                  <div class="mb-4">
                    <label class="text-sm font-medium mb-2 block">Ma note</label>
                    <div class="flex items-center space-x-2">
                      <div class="rating rating-sm">
                        <%= for i <- 1..5 do %>
                          <input
                            type="radio"
                            name={"rating-#{movie.id}"}
                            class="mask mask-star-2 bg-yellow-400 cursor-pointer"
                            value={i}
                            checked={user_movie.rating && i <= user_movie.rating}
                            phx-click="rate_movie"
                            phx-value-movie_id={movie.id}
                            phx-value-rating={i}
                          />
                        <% end %>
                      </div>
                      <%= if user_movie.rating do %>
                        <span class="text-sm font-medium"><%= user_movie.rating %>/5</span>
                      <% end %>
                    </div>
                  </div>
                  
                  <%!-- Review --%>
                  <div>
                    <label class="text-sm font-medium mb-2 block">Mon avis</label>
                    <.form
                      for={%{}}
                      phx-submit="update_review"
                      class="space-y-2"
                    >
                      <input type="hidden" name="movie_id" value={movie.id} />
                      <textarea
                        name="review"
                        class="textarea textarea-bordered w-full text-sm"
                        rows="3"
                        placeholder="Partagez votre avis sur ce film..."
                      ><%= user_movie.review %></textarea>
                      <button type="submit" class="btn btn-sm btn-primary">
                        Sauvegarder
                      </button>
                    </.form>
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
        |> assign(:watched_movies, [])
        |> assign(:page, 1)
        |> assign(:loading, false)
        |> load_watched_movies()

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

  def handle_event("rate_movie", %{"movie_id" => movie_id, "rating" => rating}, socket) do
    user_id = socket.assigns.user_id
    {rating, _} = Float.parse(rating)

    case Movies.rate_movie(user_id, String.to_integer(movie_id), %{rating: rating}) do
      {:ok, _user_movie} ->
        socket =
          socket
          |> put_flash(:info, "Note mise à jour")
          |> reload_watched_movies()

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Erreur lors de la mise à jour de la note")}
    end
  end

  def handle_event("update_review", %{"movie_id" => movie_id, "review" => review}, socket) do
    user_id = socket.assigns.user_id
    
    case Movies.rate_movie(user_id, String.to_integer(movie_id), %{review: review}) do
      {:ok, _user_movie} ->
        socket =
          socket
          |> put_flash(:info, "Avis mis à jour")
          |> reload_watched_movies()

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Erreur lors de la mise à jour de l'avis")}
    end
  end

  def handle_event("remove_movie", %{"movie_id" => movie_id}, socket) do
    user_id = socket.assigns.user_id
    
    case Movies.get_user_movie(user_id, String.to_integer(movie_id)) do
      nil ->
        {:noreply, put_flash(socket, :error, "Film non trouvé")}

      user_movie ->
        case Movies.delete_user_movie(user_movie) do
          {:ok, _} ->
            socket =
              socket
              |> put_flash(:info, "Film retiré de votre liste")
              |> reload_watched_movies()

            {:noreply, socket}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Erreur lors de la suppression")}
        end
    end
  end

  defp load_watched_movies(socket) do
    watched_movies = Movies.get_watched_movies(socket.assigns.user_id, limit: 20)
    assign(socket, :watched_movies, watched_movies)
  end

  defp load_more_movies(socket, page) do
    offset = (page - 1) * 20
    new_movies = Movies.get_watched_movies(socket.assigns.user_id, limit: 20, offset: offset)
    current_movies = socket.assigns.watched_movies

    socket
    |> assign(:watched_movies, current_movies ++ new_movies)
    |> assign(:loading, false)
  end

  defp reload_watched_movies(socket) do
    watched_movies = Movies.get_watched_movies(socket.assigns.user_id, limit: socket.assigns.page * 20)
    assign(socket, :watched_movies, watched_movies)
  end
end
