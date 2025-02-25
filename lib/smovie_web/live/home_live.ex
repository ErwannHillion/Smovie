defmodule SmovieWeb.HomeLive do
  use Phoenix.LiveView
  alias Smovie.TMDB

  def mount(_params, _session, socket) do
    if connected?(socket), do: send(self(), :load_latest_movies)
    {:ok, assign(socket, latest_movies: [])}
  end

  def handle_info(:load_latest_movies, socket) do
    case TMDB.get_latest_movies() do
      {:ok, %{"results" => results}} ->
        {:noreply, assign(socket, latest_movies: results)}

      {:error, _reason} ->
        {:noreply, assign(socket, latest_movies: [])}
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
          </li>
        <% end %>
      </ul>
    </div>
    """
  end
end
