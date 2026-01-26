defmodule SmovieWeb.UsersLive do
  use SmovieWeb, :live_view

  alias Smovie.Accounts
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
              <span class="text-lg text-primary-content">Membres</span>
            </div>
            
            <div class="flex items-center space-x-4">
              <.link navigate={~p"/my-movies"} class="btn btn-ghost text-primary-content">
                Mes films
              </.link>
              <.link navigate={~p"/watchlist"} class="btn btn-ghost text-primary-content">
                À regarder
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
        <%= if @selected_user do %>
          <%!-- Vue détaillée d'un utilisateur --%>
          <div class="mb-6">
            <button
              phx-click="close_user"
              class="btn btn-ghost btn-sm mb-4"
            >
              <.icon name="hero-arrow-left" class="w-4 h-4 mr-1" />
              Retour à la liste
            </button>
            
            <div class="flex items-center space-x-4 mb-6">
              <div class="avatar placeholder">
                <div class="bg-neutral text-neutral-content rounded-full w-16">
                  <span class="text-xl">
                    <%= String.first(@selected_user.email) |> String.upcase() %>
                  </span>
                </div>
              </div>
              <div>
                <h1 class="text-2xl font-bold"><%= @selected_user.email %></h1>
                <p class="text-base-content/70">
                  <%= @selected_user.movie_count %> film<%= if @selected_user.movie_count > 1, do: "s" %> vu<%= if @selected_user.movie_count > 1, do: "s" %>
                </p>
              </div>
            </div>
          </div>

          <%!-- Films de l'utilisateur --%>
          <%= if @user_movies == [] and not @loading do %>
            <div class="text-center py-16">
              <.icon name="hero-film" class="w-16 h-16 text-base-content/20 mx-auto mb-4" />
              <h2 class="text-xl font-semibold mb-2">Aucun film vu</h2>
              <p class="text-base-content/70">
                Cet utilisateur n'a encore vu aucun film
              </p>
            </div>
          <% else %>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              <%= for {user_movie, movie} <- @user_movies do %>
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
                    
                    <!-- Rating -->
                    <%= if user_movie.rating do %>
                      <div class="flex items-center mb-2">
                        <div class="rating rating-sm">
                          <%= for i <- 1..5 do %>
                            <input
                              type="radio"
                              class="mask mask-star-2 bg-yellow-400"
                              disabled
                              {if i <= user_movie.rating, do: [checked: true], else: []}
                            />
                          <% end %>
                        </div>
                        <span class="ml-2 text-sm font-medium"><%= user_movie.rating %>/5</span>
                      </div>
                    <% end %>
                    
                    <!-- Review -->
                    <%= if user_movie.review do %>
                      <div class="mt-2">
                        <p class="text-sm text-base-content/80 italic">
                          "<%= user_movie.review %>"
                        </p>
                      </div>
                    <% end %>
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
        <% else %>
          <%!-- Liste des utilisateurs --%>
          <div class="mb-6">
            <h1 class="text-3xl font-bold mb-2">Membres de la communauté</h1>
            <p class="text-base-content/70">
              Découvrez les films vus par les autres membres
            </p>
          </div>

          <%= if @users == [] do %>
            <div class="text-center py-16">
              <.icon name="hero-users" class="w-16 h-16 text-base-content/20 mx-auto mb-4" />
              <h2 class="text-xl font-semibold mb-2">Aucun membre</h2>
              <p class="text-base-content/70">
                Aucun membre n'a encore rejoint la communauté
              </p>
            </div>
          <% else %>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              <%= for user <- @users do %>
                <div class="card bg-base-100 shadow-xl hover:shadow-2xl transition-shadow cursor-pointer">
                  <div
                    class="card-body p-6"
                    phx-click="select_user"
                    phx-value-user_id={user.id}
                  >
                    <div class="flex items-center space-x-4">
                      <div class="avatar placeholder">
                        <div class="bg-neutral text-neutral-content rounded-full w-12">
                          <span class="text-lg">
                            <%= String.first(user.email) |> String.upcase() %>
                          </span>
                        </div>
                      </div>
                      <div class="flex-1">
                        <h3 class="card-title text-lg">
                          <%= user.email %>
                        </h3>
                        <p class="text-base-content/70">
                          <%= user.movie_count %> film<%= if user.movie_count > 1, do: "s" %> vu<%= if user.movie_count > 1, do: "s" %>
                        </p>
                      </div>
                      <div class="flex items-center">
                        <.icon name="hero-chevron-right" class="w-5 h-5 text-base-content/50" />
                      </div>
                    </div>
                    
                    <div class="text-xs text-base-content/50 mt-2">
                      Membre depuis <%= Calendar.strftime(user.inserted_at, "%B %Y") %>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    users = Accounts.list_users_with_movie_count()
    
    socket =
      socket
      |> assign(:users, users)
      |> assign(:selected_user, nil)
      |> assign(:user_movies, [])
      |> assign(:page, 1)
      |> assign(:loading, false)

    {:ok, socket}
  end

  def handle_event("select_user", %{"user_id" => user_id}, socket) do
    user_id = String.to_integer(user_id)
    user = Enum.find(socket.assigns.users, &(&1.id == user_id))
    
    socket =
      socket
      |> assign(:selected_user, user)
      |> assign(:user_movies, [])
      |> assign(:page, 1)
      |> assign(:loading, true)
      |> load_user_movies(user_id)

    {:noreply, socket}
  end

  def handle_event("load_more", _params, socket) do
    if socket.assigns.selected_user do
      new_page = socket.assigns.page + 1
      
      socket =
        socket
        |> assign(:page, new_page)
        |> assign(:loading, true)
        |> load_more_user_movies(socket.assigns.selected_user.id, new_page)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("close_user", _params, socket) do
    socket =
      socket
      |> assign(:selected_user, nil)
      |> assign(:user_movies, [])
      |> assign(:page, 1)

    {:noreply, socket}
  end

  defp load_user_movies(socket, user_id) do
    user_movies = Movies.get_watched_movies(user_id, limit: 20)
    
    socket
    |> assign(:user_movies, user_movies)
    |> assign(:loading, false)
  end

  defp load_more_user_movies(socket, user_id, page) do
    offset = (page - 1) * 20
    new_movies = Movies.get_watched_movies(user_id, limit: 20, offset: offset)
    current_movies = socket.assigns.user_movies

    socket
    |> assign(:user_movies, current_movies ++ new_movies)
    |> assign(:loading, false)
  end
end
