defmodule SmovieWeb.HomeLive do
  use SmovieWeb, :live_view

  alias Smovie.Movies

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-100">
      <%!-- Header Mobile First --%>
      <header class="bg-primary shadow-lg sticky top-0 z-50">
        <div class="container mx-auto px-4">
          <div class="flex items-center justify-between py-3 md:py-4">
            <.link navigate={~p"/"} class="text-xl md:text-2xl font-bold text-primary-content">
              SMovie
            </.link>

            <%!-- Mobile menu button --%>
            <button
              phx-click="toggle_menu"
              class="md:hidden btn btn-ghost btn-sm text-primary-content"
            >
              <.icon name={if @menu_open, do: "hero-x-mark", else: "hero-bars-3"} class="w-6 h-6" />
            </button>

            <%!-- Desktop nav --%>
            <nav class="hidden md:flex items-center gap-2">
              <%= if @current_scope do %>
                <.link navigate={~p"/my-movies"} class="btn btn-ghost btn-sm text-primary-content">
                  Mes films
                </.link>
                <.link navigate={~p"/watchlist"} class="btn btn-ghost btn-sm text-primary-content">
                  À regarder
                </.link>
              <% end %>
              <.link navigate={~p"/users"} class="btn btn-ghost btn-sm text-primary-content">
                Membres
              </.link>
              <button phx-click="toggle_theme" class="btn btn-ghost btn-sm btn-circle text-primary-content">
                <.icon name={if @theme == "dark", do: "hero-sun", else: "hero-moon"} class="w-5 h-5" />
              </button>
              <%!-- Auth links --%>
              <%= if @current_scope do %>
                <div class="dropdown dropdown-end">
                  <div tabindex="0" role="button" class="btn btn-ghost btn-sm text-primary-content">
                    <.icon name="hero-user-circle" class="w-5 h-5" />
                  </div>
                  <ul tabindex="0" class="dropdown-content menu bg-base-200 rounded-box z-[1] w-52 p-2 shadow-lg">
                    <li class="menu-title text-xs opacity-70"><%= @current_scope.user.email %></li>
                    <li><.link href={~p"/users/settings"}>Paramètres</.link></li>
                    <li><.link href={~p"/users/log-out"} method="delete">Déconnexion</.link></li>
                  </ul>
                </div>
              <% else %>
                <.link href={~p"/users/log-in"} class="btn btn-ghost btn-sm text-primary-content">
                  Connexion
                </.link>
                <.link href={~p"/users/register"} class="btn btn-sm btn-secondary">
                  Inscription
                </.link>
              <% end %>
            </nav>
          </div>

          <%!-- Mobile nav --%>
          <%= if @menu_open do %>
            <nav class="md:hidden pb-4 flex flex-col gap-2">
              <%= if @current_scope do %>
                <.link navigate={~p"/my-movies"} class="btn btn-ghost justify-start text-primary-content">
                  <.icon name="hero-film" class="w-5 h-5" />
                  Mes films
                </.link>
                <.link navigate={~p"/watchlist"} class="btn btn-ghost justify-start text-primary-content">
                  <.icon name="hero-bookmark" class="w-5 h-5" />
                  À regarder
                </.link>
              <% end %>
              <.link navigate={~p"/users"} class="btn btn-ghost justify-start text-primary-content">
                <.icon name="hero-users" class="w-5 h-5" />
                Membres
              </.link>
              <button phx-click="toggle_theme" class="btn btn-ghost justify-start text-primary-content">
                <.icon name={if @theme == "dark", do: "hero-sun", else: "hero-moon"} class="w-5 h-5" />
                <%= if @theme == "dark", do: "Mode clair", else: "Mode sombre" %>
              </button>
              <div class="divider my-1"></div>
              <%= if @current_scope do %>
                <div class="px-4 py-2 text-primary-content/70 text-sm">
                  <%= @current_scope.user.email %>
                </div>
                <.link href={~p"/users/settings"} class="btn btn-ghost justify-start text-primary-content">
                  <.icon name="hero-cog-6-tooth" class="w-5 h-5" />
                  Paramètres
                </.link>
                <.link href={~p"/users/log-out"} method="delete" class="btn btn-ghost justify-start text-primary-content">
                  <.icon name="hero-arrow-right-on-rectangle" class="w-5 h-5" />
                  Déconnexion
                </.link>
              <% else %>
                <.link href={~p"/users/log-in"} class="btn btn-ghost justify-start text-primary-content">
                  <.icon name="hero-arrow-left-on-rectangle" class="w-5 h-5" />
                  Connexion
                </.link>
                <.link href={~p"/users/register"} class="btn btn-secondary justify-start">
                  <.icon name="hero-user-plus" class="w-5 h-5" />
                  Inscription
                </.link>
              <% end %>
            </nav>
          <% end %>
        </div>
      </header>

      <%!-- Main content --%>
      <main class="container mx-auto px-4 py-6 md:py-8">
        <%!-- Search section --%>
        <section class="mb-6 md:mb-8">
          <h1 class="text-2xl md:text-3xl font-bold mb-4">Découvrez des films</h1>
          <.form for={%{}} phx-submit="search" class="flex flex-col sm:flex-row gap-2">
            <input
              type="text"
              name="query"
              value={@query}
              placeholder="Rechercher un film..."
              class="input input-bordered w-full"
              phx-debounce="300"
            />
            <button type="submit" class="btn btn-primary w-full sm:w-auto">
              <.icon name="hero-magnifying-glass" class="w-5 h-5" />
              <span class="sm:inline">Rechercher</span>
            </button>
          </.form>
        </section>

        <%!-- Search Results --%>
        <%= if @loading do %>
          <div class="flex justify-center py-16">
            <span class="loading loading-spinner loading-lg text-primary"></span>
          </div>
        <% else %>
          <%= if @query != "" do %>
            <%= if @movies == [] do %>
              <div class="text-center py-16">
                <.icon name="hero-film" class="w-16 h-16 text-base-content/20 mx-auto mb-4" />
                <h2 class="text-xl font-semibold mb-2">Aucun résultat</h2>
                <p class="text-base-content/70">
                  Aucun film trouvé pour "<%= @query %>"
                </p>
              </div>
            <% else %>
              <section>
                <h2 class="text-xl md:text-2xl font-bold mb-4">
                  Résultats pour "<%= @query %>"
                </h2>
                <.movie_grid movies={@movies} current_scope={@current_scope} />

                <%= if @has_more do %>
                  <div class="flex justify-center mt-6 md:mt-8">
                    <button phx-click="load_more" class="btn btn-outline btn-primary">
                      <.icon name="hero-arrow-down" class="w-5 h-5" />
                      Charger plus
                    </button>
                  </div>
                <% end %>
              </section>
            <% end %>
          <% else %>
            <%!-- Followed users activity --%>
            <%= if @current_scope && @followed_activity != [] do %>
              <section class="mb-8">
                <h2 class="text-xl md:text-2xl font-bold mb-4">
                  <.icon name="hero-users" class="w-6 h-6 inline-block mr-2" />
                  Activité de vos abonnements
                </h2>
                <div class="overflow-x-auto pb-4">
                  <div class="flex gap-4" style="min-width: max-content;">
                    <%= for {user_movie, movie, user} <- @followed_activity do %>
                      <.link navigate={~p"/movie/#{movie.tmdb_id}"} class="flex-shrink-0 w-32 md:w-40 group">
                        <div class="relative">
                          <%= if movie.poster_path do %>
                            <img
                              src={"https://image.tmdb.org/t/p/w342#{movie.poster_path}"}
                              alt={movie.title}
                              class="w-full aspect-[2/3] object-cover rounded-lg shadow-lg group-hover:shadow-xl transition-shadow"
                            />
                          <% else %>
                            <div class="w-full aspect-[2/3] bg-base-300 rounded-lg flex items-center justify-center">
                              <.icon name="hero-photo" class="w-8 h-8 text-base-content/20" />
                            </div>
                          <% end %>
                          <%= if user_movie.rating do %>
                            <div class="absolute top-1 right-1 badge badge-sm badge-primary">
                              <%= user_movie.rating %>/5
                            </div>
                          <% end %>
                        </div>
                        <div class="mt-2">
                          <p class="font-medium text-sm line-clamp-1"><%= movie.title %></p>
                          <p class="text-xs text-base-content/60">
                            vu par <%= String.split(user.email, "@") |> List.first() %>
                          </p>
                        </div>
                      </.link>
                    <% end %>
                  </div>
                </div>
              </section>
            <% end %>

            <%!-- Popular movies with pagination --%>
            <section>
              <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-4">
                <h2 class="text-xl md:text-2xl font-bold">Films populaires</h2>

                <%!-- Pagination controls --%>
                <div class="flex items-center gap-2">
                  <button
                    phx-click="prev_popular_page"
                    disabled={@popular_page == 1}
                    class="btn btn-sm btn-outline btn-primary"
                  >
                    <.icon name="hero-chevron-left" class="w-4 h-4" />
                    <span class="hidden sm:inline">Précédent</span>
                  </button>
                  <span class="text-sm text-base-content/70 px-2">
                    Page <%= @popular_page %>
                  </span>
                  <button
                    phx-click="next_popular_page"
                    disabled={not @popular_has_more}
                    class="btn btn-sm btn-outline btn-primary"
                  >
                    <span class="hidden sm:inline">Suivant</span>
                    <.icon name="hero-chevron-right" class="w-4 h-4" />
                  </button>
                </div>
              </div>

              <%= if @popular_loading do %>
                <div class="flex justify-center py-16">
                  <span class="loading loading-spinner loading-lg text-primary"></span>
                </div>
              <% else %>
                <.movie_grid movies={@popular_movies} current_scope={@current_scope} />
              <% end %>

              <%!-- Bottom pagination --%>
              <div class="flex justify-center mt-6 md:mt-8">
                <div class="join">
                  <button
                    phx-click="prev_popular_page"
                    disabled={@popular_page == 1}
                    class="join-item btn btn-outline"
                  >
                    <.icon name="hero-chevron-left" class="w-4 h-4" />
                  </button>
                  <%= for page <- visible_pages(@popular_page) do %>
                    <button
                      phx-click="go_to_popular_page"
                      phx-value-page={page}
                      class={"join-item btn #{if page == @popular_page, do: "btn-primary", else: "btn-outline"}"}
                    >
                      <%= page %>
                    </button>
                  <% end %>
                  <button
                    phx-click="next_popular_page"
                    disabled={not @popular_has_more}
                    class="join-item btn btn-outline"
                  >
                    <.icon name="hero-chevron-right" class="w-4 h-4" />
                  </button>
                </div>
              </div>
            </section>
          <% end %>
        <% end %>
      </main>

      <%!-- Rating Modal --%>
      <%= if @show_rating_modal do %>
        <div class="modal modal-open">
          <div class="modal-box">
            <button phx-click="close_rating_modal" class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2">
              <.icon name="hero-x-mark" class="w-5 h-5" />
            </button>

            <h3 class="font-bold text-lg mb-4">Noter ce film</h3>

            <%= if @rating_movie do %>
              <div class="flex gap-4 mb-4">
                <%= if @rating_movie["poster_path"] do %>
                  <img
                    src={"https://image.tmdb.org/t/p/w92#{@rating_movie["poster_path"]}"}
                    alt={@rating_movie["title"]}
                    class="w-16 rounded"
                  />
                <% end %>
                <div>
                  <p class="font-semibold"><%= @rating_movie["title"] %></p>
                  <p class="text-sm text-base-content/60">
                    <%= if @rating_movie["release_date"], do: String.slice(@rating_movie["release_date"], 0, 4) %>
                  </p>
                </div>
              </div>
            <% end %>

            <.form for={@rating_form} phx-submit="save_rating" class="space-y-4">
              <div>
                <label class="label">
                  <span class="label-text font-medium">Ma note</span>
                </label>
                <div class="flex items-center gap-4">
                  <input
                    type="range"
                    name="rating"
                    min="0"
                    max="5"
                    step="0.5"
                    value={@rating_value}
                    phx-change="update_rating_preview"
                    class="range range-primary flex-1"
                  />
                  <span class="badge badge-lg badge-primary min-w-[4rem] justify-center">
                    <%= @rating_value %>/5
                  </span>
                </div>
              </div>

              <div>
                <label class="label">
                  <span class="label-text font-medium">Mon avis (optionnel)</span>
                </label>
                <textarea
                  name="review"
                  class="textarea textarea-bordered w-full"
                  rows="4"
                  placeholder="Partagez votre avis sur ce film..."
                ><%= @review_value %></textarea>
              </div>

              <div class="modal-action">
                <button type="button" phx-click="close_rating_modal" class="btn btn-ghost">
                  Annuler
                </button>
                <button type="submit" class="btn btn-primary">
                  <.icon name="hero-check" class="w-5 h-5" />
                  Enregistrer
                </button>
              </div>
            </.form>
          </div>
          <div class="modal-backdrop bg-black/50" phx-click="close_rating_modal"></div>
        </div>
      <% end %>
    </div>
    """
  end

  # Movie card grid component - now with clickable cards
  defp movie_grid(assigns) do
    ~H"""
    <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-3 md:gap-4 lg:gap-6">
      <%= for movie <- @movies do %>
        <div class="card bg-base-200 shadow-lg hover:shadow-xl hover:scale-[1.02] transition-all duration-200">
          <.link navigate={~p"/movie/#{movie["id"]}"} class="cursor-pointer">
            <figure class="relative aspect-[2/3]">
              <%= if movie["poster_path"] do %>
                <img
                  src={"https://image.tmdb.org/t/p/w342#{movie["poster_path"]}"}
                  alt={movie["title"]}
                  class="w-full h-full object-cover"
                  loading="lazy"
                />
              <% else %>
                <div class="w-full h-full bg-base-300 flex items-center justify-center">
                  <.icon name="hero-photo" class="w-12 h-12 text-base-content/20" />
                </div>
              <% end %>

              <%!-- Rating badge --%>
              <%= if movie["vote_average"] && movie["vote_average"] > 0 do %>
                <div class="absolute top-1 left-1 md:top-2 md:left-2 badge badge-sm md:badge-md badge-primary gap-1">
                  <.icon name="hero-star-solid" class="w-3 h-3" />
                  <%= Float.round(movie["vote_average"], 1) %>
                </div>
              <% end %>
            </figure>
          </.link>

          <div class="card-body p-2 md:p-4">
            <.link navigate={~p"/movie/#{movie["id"]}"}>
              <h3 class="font-semibold text-sm md:text-base leading-tight line-clamp-2 hover:text-primary transition-colors">
                <%= movie["title"] %>
              </h3>
            </.link>

            <p class="text-xs md:text-sm text-base-content/60">
              <%= if movie["release_date"] && movie["release_date"] != "" do %>
                <%= String.slice(movie["release_date"], 0, 4) %>
              <% else %>
                -
              <% end %>
            </p>

            <%!-- Actions --%>
            <%= if @current_scope do %>
              <div class="card-actions justify-end mt-2">
                <button
                  phx-click="add_to_watchlist"
                  phx-value-tmdb_id={movie["id"]}
                  class="btn btn-xs md:btn-sm btn-ghost btn-circle"
                  title="Ajouter à ma liste"
                >
                  <.icon name="hero-bookmark" class="w-4 h-4" />
                </button>
                <button
                  phx-click="open_rating_modal"
                  phx-value-tmdb_id={movie["id"]}
                  phx-value-title={movie["title"]}
                  phx-value-poster={movie["poster_path"]}
                  phx-value-date={movie["release_date"]}
                  class="btn btn-xs md:btn-sm btn-primary btn-circle"
                  title="Marquer comme vu et noter"
                >
                  <.icon name="hero-eye" class="w-4 h-4" />
                </button>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp visible_pages(current_page) do
    start_page = max(1, current_page - 2)
    end_page = start_page + 4
    Enum.to_list(start_page..end_page)
  end

  def mount(_params, _session, socket) do
    theme = get_connect_params(socket)["theme"] || "dark"

    # Load followed users activity if logged in
    followed_activity =
      if socket.assigns[:current_scope] do
        Movies.get_followed_users_watched_movies(socket.assigns.current_scope.user.id, limit: 10)
      else
        []
      end

    socket =
      socket
      |> assign(:query, "")
      |> assign(:movies, [])
      |> assign(:page, 1)
      |> assign(:has_more, false)
      |> assign(:loading, false)
      |> assign(:popular_movies, [])
      |> assign(:popular_page, 1)
      |> assign(:popular_has_more, true)
      |> assign(:popular_loading, true)
      |> assign(:menu_open, false)
      |> assign(:theme, theme)
      |> assign(:followed_activity, followed_activity)
      |> assign(:show_rating_modal, false)
      |> assign(:rating_form, to_form(%{}))
      |> assign(:rating_value, 3.5)
      |> assign(:review_value, "")
      |> assign(:rating_movie, nil)
      |> assign(:rating_tmdb_id, nil)
      |> load_popular_movies(1)

    {:ok, socket}
  end

  defp load_popular_movies(socket, page) do
    case Smovie.TMDB.get_popular_movies(page) do
      {:ok, %{"results" => results, "total_pages" => total_pages}} ->
        socket
        |> assign(:popular_movies, results)
        |> assign(:popular_page, page)
        |> assign(:popular_has_more, page < total_pages)
        |> assign(:popular_loading, false)

      _ ->
        socket
        |> assign(:popular_movies, [])
        |> assign(:popular_loading, false)
    end
  end

  def handle_event("toggle_menu", _params, socket) do
    {:noreply, assign(socket, :menu_open, not socket.assigns.menu_open)}
  end

  def handle_event("toggle_theme", _params, socket) do
    new_theme = if socket.assigns.theme == "dark", do: "light", else: "dark"

    {:noreply,
     socket
     |> assign(:theme, new_theme)
     |> push_event("set-theme", %{theme: new_theme})}
  end

  def handle_event("search", %{"query" => query}, socket) do
    if query == "" do
      socket =
        socket
        |> assign(movies: [], query: "", page: 1, has_more: false)
        |> assign(:popular_loading, true)
        |> load_popular_movies(1)

      {:noreply, socket}
    else
      socket = assign(socket, loading: true, query: query, page: 1, menu_open: false)

      case Movies.search_movies_tmdb(query, 1) do
        {:ok, %{"results" => results, "total_pages" => total_pages}} ->
          {:noreply,
           assign(socket,
             movies: results,
             loading: false,
             has_more: total_pages > 1
           )}

        _ ->
          {:noreply, assign(socket, movies: [], loading: false, has_more: false)}
      end
    end
  end

  def handle_event("load_more", _params, socket) do
    new_page = socket.assigns.page + 1

    case Movies.search_movies_tmdb(socket.assigns.query, new_page) do
      {:ok, %{"results" => results, "total_pages" => total_pages}} ->
        {:noreply,
         assign(socket,
           movies: socket.assigns.movies ++ results,
           page: new_page,
           has_more: new_page < total_pages
         )}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("prev_popular_page", _params, socket) do
    if socket.assigns.popular_page > 1 do
      new_page = socket.assigns.popular_page - 1

      socket =
        socket
        |> assign(:popular_loading, true)
        |> load_popular_movies(new_page)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("next_popular_page", _params, socket) do
    if socket.assigns.popular_has_more do
      new_page = socket.assigns.popular_page + 1

      socket =
        socket
        |> assign(:popular_loading, true)
        |> load_popular_movies(new_page)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("go_to_popular_page", %{"page" => page}, socket) do
    page = String.to_integer(page)

    socket =
      socket
      |> assign(:popular_loading, true)
      |> load_popular_movies(page)

    {:noreply, socket}
  end

  def handle_event("add_to_watchlist", %{"tmdb_id" => tmdb_id}, socket) do
    if socket.assigns.current_scope do
      user_id = socket.assigns.current_scope.user.id
      tmdb_id = String.to_integer(tmdb_id)

      case Movies.add_to_watchlist_from_tmdb(user_id, tmdb_id) do
        {:ok, _} ->
          {:noreply, put_flash(socket, :info, "Film ajouté à votre liste")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Erreur lors de l'ajout")}
      end
    else
      {:noreply, redirect(socket, to: ~p"/users/log-in")}
    end
  end

  def handle_event("open_rating_modal", params, socket) do
    if socket.assigns.current_scope do
      movie = %{
        "id" => params["tmdb_id"],
        "title" => params["title"],
        "poster_path" => params["poster"],
        "release_date" => params["date"]
      }

      {:noreply,
       socket
       |> assign(:show_rating_modal, true)
       |> assign(:rating_movie, movie)
       |> assign(:rating_tmdb_id, String.to_integer(params["tmdb_id"]))
       |> assign(:rating_value, 3.5)
       |> assign(:review_value, "")}
    else
      {:noreply, redirect(socket, to: ~p"/users/log-in")}
    end
  end

  def handle_event("close_rating_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_rating_modal, false)
     |> assign(:rating_movie, nil)
     |> assign(:rating_tmdb_id, nil)}
  end

  def handle_event("update_rating_preview", %{"rating" => rating}, socket) do
    value = parse_rating(rating)
    {:noreply, assign(socket, :rating_value, value)}
  end

  defp parse_rating(rating) when is_binary(rating) do
    case Float.parse(rating) do
      {value, _} -> value
      :error -> 3.5
    end
  end

  def handle_event("save_rating", %{"rating" => rating, "review" => review}, socket) do
    if socket.assigns.current_scope && socket.assigns.rating_tmdb_id do
      user_id = socket.assigns.current_scope.user.id
      tmdb_id = socket.assigns.rating_tmdb_id
      rating = parse_rating(rating)

      # First ensure the movie exists in our DB
      case Smovie.TMDB.create_or_update_movie_from_tmdb(tmdb_id) do
        {:ok, movie} ->
          attrs = %{
            rating: rating,
            review: review,
            status: "watched",
            watched_at: DateTime.utc_now()
          }

          case Movies.rate_movie(user_id, movie.id, attrs) do
            {:ok, _user_movie} ->
              # Reload followed activity
              followed_activity =
                Movies.get_followed_users_watched_movies(user_id, limit: 10)

              {:noreply,
               socket
               |> assign(:show_rating_modal, false)
               |> assign(:rating_movie, nil)
               |> assign(:rating_tmdb_id, nil)
               |> assign(:followed_activity, followed_activity)
               |> put_flash(:info, "Film noté avec succès !")}

            {:error, _} ->
              {:noreply, put_flash(socket, :error, "Erreur lors de l'enregistrement")}
          end

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Erreur lors de la récupération du film")}
      end
    else
      {:noreply, socket}
    end
  end
end
