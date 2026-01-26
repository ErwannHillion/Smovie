defmodule SmovieWeb.MovieLive do
  use SmovieWeb, :live_view

  alias Smovie.Movies
  alias Smovie.TMDB

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-100">
      <%!-- Header --%>
      <header class="bg-primary shadow-lg sticky top-0 z-50">
        <div class="container mx-auto px-4">
          <div class="flex items-center justify-between py-3 md:py-4">
            <div class="flex items-center gap-2">
              <.link navigate={~p"/"} class="btn btn-ghost btn-sm btn-circle text-primary-content">
                <.icon name="hero-arrow-left" class="w-5 h-5" />
              </.link>
              <.link navigate={~p"/"} class="text-xl md:text-2xl font-bold text-primary-content">
                SMovie
              </.link>
            </div>

            <div class="flex items-center gap-2">
              <button phx-click="toggle_theme" class="btn btn-ghost btn-sm btn-circle text-primary-content">
                <.icon name={if @theme == "dark", do: "hero-sun", else: "hero-moon"} class="w-5 h-5" />
              </button>
            </div>
          </div>
        </div>
      </header>

      <%= if @loading do %>
        <div class="flex justify-center items-center py-32">
          <span class="loading loading-spinner loading-lg text-primary"></span>
        </div>
      <% else %>
        <%= if @movie do %>
          <%!-- Backdrop --%>
          <%= if @movie["backdrop_path"] do %>
            <div class="relative h-48 md:h-64 lg:h-80 overflow-hidden">
              <img
                src={"https://image.tmdb.org/t/p/w1280#{@movie["backdrop_path"]}"}
                alt=""
                class="w-full h-full object-cover"
              />
              <div class="absolute inset-0 bg-gradient-to-t from-base-100 via-base-100/50 to-transparent"></div>
            </div>
          <% end %>

          <main class="container mx-auto px-4 py-6 md:py-8">
            <div class="flex flex-col md:flex-row gap-6 md:gap-8 -mt-24 md:-mt-32 relative z-10">
              <%!-- Poster --%>
              <div class="flex-shrink-0 mx-auto md:mx-0">
                <div class="w-40 md:w-56 lg:w-64 rounded-lg overflow-hidden shadow-2xl">
                  <%= if @movie["poster_path"] do %>
                    <img
                      src={"https://image.tmdb.org/t/p/w500#{@movie["poster_path"]}"}
                      alt={@movie["title"]}
                      class="w-full"
                    />
                  <% else %>
                    <div class="aspect-[2/3] bg-base-300 flex items-center justify-center">
                      <.icon name="hero-photo" class="w-16 h-16 text-base-content/20" />
                    </div>
                  <% end %>
                </div>
              </div>

              <%!-- Info --%>
              <div class="flex-1 text-center md:text-left">
                <h1 class="text-2xl md:text-3xl lg:text-4xl font-bold mb-2">
                  <%= @movie["title"] %>
                </h1>

                <%= if @movie["original_title"] && @movie["original_title"] != @movie["title"] do %>
                  <p class="text-base-content/60 mb-2 text-sm md:text-base">
                    <%= @movie["original_title"] %>
                  </p>
                <% end %>

                <div class="flex flex-wrap justify-center md:justify-start gap-2 mb-4">
                  <%= if @movie["release_date"] && @movie["release_date"] != "" do %>
                    <span class="badge badge-outline">
                      <%= String.slice(@movie["release_date"], 0, 4) %>
                    </span>
                  <% end %>
                  <%= if @movie["runtime"] do %>
                    <span class="badge badge-outline">
                      <%= @movie["runtime"] %> min
                    </span>
                  <% end %>
                  <%= if @movie["vote_average"] && @movie["vote_average"] > 0 do %>
                    <span class="badge badge-primary gap-1">
                      <.icon name="hero-star-solid" class="w-3 h-3" />
                      <%= Float.round(@movie["vote_average"], 1) %>/10
                    </span>
                  <% end %>
                </div>

                <%!-- Genres --%>
                <%= if @movie["genres"] && @movie["genres"] != [] do %>
                  <div class="flex flex-wrap justify-center md:justify-start gap-2 mb-4">
                    <%= for genre <- @movie["genres"] do %>
                      <span class="badge badge-secondary badge-sm">
                        <%= genre["name"] %>
                      </span>
                    <% end %>
                  </div>
                <% end %>

                <%!-- Site average rating --%>
                <%= if @site_rating && @site_rating.count > 0 do %>
                  <div class="flex items-center justify-center md:justify-start gap-2 mb-4 p-3 bg-base-200 rounded-lg inline-flex">
                    <.icon name="hero-users" class="w-5 h-5 text-primary" />
                    <span class="font-semibold">
                      <%= if @site_rating.average, do: Float.round(@site_rating.average, 1), else: "-" %>/5
                    </span>
                    <span class="text-base-content/60 text-sm">
                      (<%= @site_rating.count %> avis SMovie)
                    </span>
                  </div>
                <% end %>

                <%!-- Actions --%>
                <%= if @current_scope do %>
                  <div class="flex flex-wrap justify-center md:justify-start gap-2 mb-6">
                    <%= if @user_movie && @user_movie.status == "watched" do %>
                      <button class="btn btn-success gap-2" disabled>
                        <.icon name="hero-check" class="w-5 h-5" />
                        Déjà vu
                      </button>
                      <button phx-click="open_rating_modal" class="btn btn-outline btn-primary gap-2">
                        <.icon name="hero-pencil" class="w-5 h-5" />
                        Modifier ma note
                      </button>
                    <% else %>
                      <button phx-click="open_rating_modal" class="btn btn-primary gap-2">
                        <.icon name="hero-eye" class="w-5 h-5" />
                        Marquer comme vu
                      </button>
                      <%= if @user_movie && @user_movie.status == "watchlist" do %>
                        <button class="btn btn-outline gap-2" disabled>
                          <.icon name="hero-bookmark-solid" class="w-5 h-5" />
                          Dans ma liste
                        </button>
                      <% else %>
                        <button phx-click="add_to_watchlist" class="btn btn-outline gap-2">
                          <.icon name="hero-bookmark" class="w-5 h-5" />
                          À regarder
                        </button>
                      <% end %>
                    <% end %>
                  </div>
                <% else %>
                  <div class="mb-6">
                    <.link href={~p"/users/log-in"} class="btn btn-primary">
                      Connectez-vous pour noter ce film
                    </.link>
                  </div>
                <% end %>

                <%!-- Synopsis --%>
                <%= if @movie["overview"] && @movie["overview"] != "" do %>
                  <div class="mb-6">
                    <h2 class="text-lg font-semibold mb-2">Synopsis</h2>
                    <p class="text-base-content/80 leading-relaxed">
                      <%= @movie["overview"] %>
                    </p>
                  </div>
                <% end %>

                <%!-- Director & Cast --%>
                <%= if @movie["credits"] do %>
                  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <%= if director = get_director(@movie["credits"]) do %>
                      <div>
                        <h3 class="text-sm font-semibold text-base-content/60 mb-1">Réalisateur</h3>
                        <p><%= director %></p>
                      </div>
                    <% end %>
                    <%= if cast = get_cast(@movie["credits"]) do %>
                      <div>
                        <h3 class="text-sm font-semibold text-base-content/60 mb-1">Casting</h3>
                        <p class="text-sm"><%= Enum.join(cast, ", ") %></p>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>

            <%!-- User reviews section --%>
            <section class="mt-8 md:mt-12">
              <h2 class="text-xl md:text-2xl font-bold mb-4">Avis des membres SMovie</h2>

              <%= if @reviews == [] do %>
                <div class="text-center py-8 bg-base-200 rounded-lg">
                  <.icon name="hero-chat-bubble-left-right" class="w-12 h-12 text-base-content/20 mx-auto mb-2" />
                  <p class="text-base-content/60">Aucun avis pour le moment</p>
                  <%= if @current_scope do %>
                    <p class="text-sm text-base-content/40 mt-1">Soyez le premier à donner votre avis !</p>
                  <% end %>
                </div>
              <% else %>
                <div class="space-y-4">
                  <%= for {user_movie, user} <- @reviews do %>
                    <div class="card bg-base-200">
                      <div class="card-body p-4">
                        <div class="flex items-start gap-3">
                          <div class="avatar placeholder">
                            <div class="bg-neutral text-neutral-content rounded-full w-10">
                              <span><%= String.first(user.email) |> String.upcase() %></span>
                            </div>
                          </div>
                          <div class="flex-1">
                            <div class="flex items-center justify-between mb-1">
                              <span class="font-semibold text-sm"><%= user.email %></span>
                              <%= if user_movie.rating do %>
                                <span class="badge badge-primary badge-sm gap-1">
                                  <.icon name="hero-star-solid" class="w-3 h-3" />
                                  <%= user_movie.rating %>/5
                                </span>
                              <% end %>
                            </div>
                            <%= if user_movie.review && user_movie.review != "" do %>
                              <p class="text-base-content/80 text-sm"><%= user_movie.review %></p>
                            <% end %>
                            <%= if user_movie.watched_at do %>
                              <p class="text-xs text-base-content/50 mt-2">
                                Vu le <%= Calendar.strftime(user_movie.watched_at, "%d/%m/%Y") %>
                              </p>
                            <% end %>
                          </div>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </section>
          </main>
        <% else %>
          <div class="text-center py-16">
            <.icon name="hero-exclamation-triangle" class="w-16 h-16 text-warning mx-auto mb-4" />
            <h2 class="text-xl font-semibold mb-2">Film non trouvé</h2>
            <p class="text-base-content/70 mb-4">Ce film n'existe pas ou n'est plus disponible.</p>
            <.link navigate={~p"/"} class="btn btn-primary">
              Retour à l'accueil
            </.link>
          </div>
        <% end %>
      <% end %>

      <%!-- Rating Modal --%>
      <%= if @show_rating_modal do %>
        <div class="modal modal-open">
          <div class="modal-box">
            <button phx-click="close_rating_modal" class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2">
              <.icon name="hero-x-mark" class="w-5 h-5" />
            </button>

            <h3 class="font-bold text-lg mb-4">
              <%= if @user_movie && @user_movie.status == "watched", do: "Modifier ma note", else: "Noter ce film" %>
            </h3>

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

  defp get_director(%{"crew" => crew}) when is_list(crew) do
    case Enum.find(crew, &(&1["job"] == "Director")) do
      nil -> nil
      director -> director["name"]
    end
  end
  defp get_director(_), do: nil

  defp get_cast(%{"cast" => cast}) when is_list(cast) do
    cast
    |> Enum.take(5)
    |> Enum.map(& &1["name"])
  end
  defp get_cast(_), do: nil

  def mount(%{"id" => tmdb_id}, _session, socket) do
    theme = get_connect_params(socket)["theme"] || "dark"
    tmdb_id = String.to_integer(tmdb_id)

    socket =
      socket
      |> assign(:tmdb_id, tmdb_id)
      |> assign(:movie, nil)
      |> assign(:loading, true)
      |> assign(:theme, theme)
      |> assign(:show_rating_modal, false)
      |> assign(:rating_form, to_form(%{}))
      |> assign(:rating_value, 3.5)
      |> assign(:review_value, "")
      |> assign(:user_movie, nil)
      |> assign(:reviews, [])
      |> assign(:site_rating, nil)

    send(self(), :load_movie)

    {:ok, socket}
  end

  def handle_info(:load_movie, socket) do
    tmdb_id = socket.assigns.tmdb_id

    case TMDB.get_movie_details(tmdb_id) do
      {:ok, movie} ->
        # Get or create local movie
        local_movie = Movies.get_movie_by_tmdb_id(tmdb_id)

        # Get user movie if logged in
        user_movie =
          if socket.assigns.current_scope do
            if local_movie do
              Movies.get_user_movie(socket.assigns.current_scope.user.id, local_movie.id)
            end
          end

        # Get reviews from site users
        reviews =
          if local_movie do
            Movies.get_movie_reviews(local_movie.id, limit: 20)
          else
            []
          end

        # Get average rating
        site_rating =
          if local_movie do
            Movies.get_movie_average_rating(local_movie.id)
          else
            %{average: nil, count: 0}
          end

        # Pre-fill rating form if user has already rated
        {rating_value, review_value} =
          if user_movie do
            {user_movie.rating || 3.5, user_movie.review || ""}
          else
            {3.5, ""}
          end

        socket =
          socket
          |> assign(:movie, movie)
          |> assign(:local_movie, local_movie)
          |> assign(:user_movie, user_movie)
          |> assign(:reviews, reviews)
          |> assign(:site_rating, site_rating)
          |> assign(:loading, false)
          |> assign(:rating_value, rating_value)
          |> assign(:review_value, review_value)

        {:noreply, socket}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:movie, nil)
         |> assign(:loading, false)}
    end
  end

  def handle_event("toggle_theme", _params, socket) do
    new_theme = if socket.assigns.theme == "dark", do: "light", else: "dark"

    {:noreply,
     socket
     |> assign(:theme, new_theme)
     |> push_event("set-theme", %{theme: new_theme})}
  end

  def handle_event("open_rating_modal", _params, socket) do
    {:noreply, assign(socket, :show_rating_modal, true)}
  end

  def handle_event("close_rating_modal", _params, socket) do
    {:noreply, assign(socket, :show_rating_modal, false)}
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
    if socket.assigns.current_scope do
      user_id = socket.assigns.current_scope.user.id
      tmdb_id = socket.assigns.tmdb_id
      rating = parse_rating(rating)

      # First ensure the movie exists in our DB
      case TMDB.create_or_update_movie_from_tmdb(tmdb_id) do
        {:ok, movie} ->
          attrs = %{
            rating: rating,
            review: review,
            status: "watched",
            watched_at: DateTime.utc_now()
          }

          case Movies.rate_movie(user_id, movie.id, attrs) do
            {:ok, user_movie} ->
              # Reload reviews
              reviews = Movies.get_movie_reviews(movie.id, limit: 20)
              site_rating = Movies.get_movie_average_rating(movie.id)

              {:noreply,
               socket
               |> assign(:user_movie, user_movie)
               |> assign(:local_movie, movie)
               |> assign(:reviews, reviews)
               |> assign(:site_rating, site_rating)
               |> assign(:show_rating_modal, false)
               |> assign(:rating_value, rating)
               |> assign(:review_value, review)
               |> put_flash(:info, "Votre avis a été enregistré")}

            {:error, _} ->
              {:noreply, put_flash(socket, :error, "Erreur lors de l'enregistrement")}
          end

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Erreur lors de la récupération du film")}
      end
    else
      {:noreply, redirect(socket, to: ~p"/users/log-in")}
    end
  end

  def handle_event("add_to_watchlist", _params, socket) do
    if socket.assigns.current_scope do
      user_id = socket.assigns.current_scope.user.id
      tmdb_id = socket.assigns.tmdb_id

      case Movies.add_to_watchlist_from_tmdb(user_id, tmdb_id) do
        {:ok, user_movie} ->
          {:noreply,
           socket
           |> assign(:user_movie, user_movie)
           |> put_flash(:info, "Film ajouté à votre liste")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Erreur lors de l'ajout")}
      end
    else
      {:noreply, redirect(socket, to: ~p"/users/log-in")}
    end
  end
end
