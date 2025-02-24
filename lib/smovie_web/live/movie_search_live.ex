defmodule SmovieWeb.MovieSearchLive do
  use Phoenix.LiveView
  alias Smovie.TMDB
  alias Phoenix.HTML

  def mount(_params, _session, socket) do
    {:ok, assign(socket, query: "", results: [])}
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
          </li>
        <% end %>
      </ul>
    </div>
    """
  end
end
