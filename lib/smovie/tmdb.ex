defmodule Smovie.TMDB do
  @moduledoc """
  Client for The Movie Database (TMDB) API.
  """

  require Logger

  @base_url "https://api.themoviedb.org/3"

  def get_api_key do
    Application.get_env(:smovie, :tmdb)[:api_key] ||
      raise "TMDB API key not configured. Please set API_KEY environment variable."
  end

  @doc """
  Searches for movies by title.
  """
  def search_movies(query, options \\ []) do
    page = Keyword.get(options, :page, 1)
    
    params = %{
      api_key: get_api_key(),
      query: query,
      page: page,
      language: "fr-FR"
    }

    case Req.get("#{@base_url}/search/movie", params: params) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        Logger.error("TMDB API error: #{status} - #{inspect(body)}")
        {:error, :api_error}

      {:error, reason} ->
        Logger.error("TMDB API request failed: #{inspect(reason)}")
        {:error, :request_failed}
    end
  end

  @doc """
  Gets movie details by TMDB ID (alias for get_movie_details).
  """
  def get_movie(tmdb_id) do
    get_movie_details(tmdb_id)
  end

  @doc """
  Gets movie details by TMDB ID.
  """
  def get_movie_details(tmdb_id) do
    params = %{
      api_key: get_api_key(),
      language: "fr-FR",
      append_to_response: "credits"
    }

    case Req.get("#{@base_url}/movie/#{tmdb_id}", params: params) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      {:ok, %{status: status, body: body}} ->
        Logger.error("TMDB API error: #{status} - #{inspect(body)}")
        {:error, :api_error}

      {:error, reason} ->
        Logger.error("TMDB API request failed: #{inspect(reason)}")
        {:error, :request_failed}
    end
  end

  @doc """
  Gets popular movies.
  """
  def get_popular_movies(page \\ 1) do
    params = %{
      api_key: get_api_key(),
      page: page,
      language: "fr-FR"
    }

    case Req.get("#{@base_url}/movie/popular", params: params) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        Logger.error("TMDB API error: #{status} - #{inspect(body)}")
        {:error, :api_error}

      {:error, reason} ->
        Logger.error("TMDB API request failed: #{inspect(reason)}")
        {:error, :request_failed}
    end
  end

  @doc """
  Gets now playing movies.
  """
  def get_now_playing_movies(page \\ 1) do
    params = %{
      api_key: get_api_key(),
      page: page,
      language: "fr-FR"
    }

    case Req.get("#{@base_url}/movie/now_playing", params: params) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        Logger.error("TMDB API error: #{status} - #{inspect(body)}")
        {:error, :api_error}

      {:error, reason} ->
        Logger.error("TMDB API request failed: #{inspect(reason)}")
        {:error, :request_failed}
    end
  end

  @doc """
  Converts TMDB movie data to our movie schema format.
  """
  def tmdb_to_movie_attrs(tmdb_movie) do
    %{
      tmdb_id: tmdb_movie["id"],
      title: tmdb_movie["title"],
      original_title: tmdb_movie["original_title"],
      overview: tmdb_movie["overview"],
      release_date: parse_date(tmdb_movie["release_date"]),
      poster_path: tmdb_movie["poster_path"],
      backdrop_path: tmdb_movie["backdrop_path"],
      vote_average: tmdb_movie["vote_average"],
      vote_count: tmdb_movie["vote_count"],
      runtime: tmdb_movie["runtime"],
      genres: extract_genres(tmdb_movie["genres"]),
      director: extract_director(tmdb_movie["credits"]),
      cast: extract_cast(tmdb_movie["credits"])
    }
  end

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil

  defp parse_date(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end

  defp extract_genres(nil), do: []
  defp extract_genres(genres) when is_list(genres) do
    Enum.map(genres, & &1["name"])
  end

  defp extract_director(nil), do: nil
  defp extract_director(%{"crew" => crew}) when is_list(crew) do
    case Enum.find(crew, &(&1["job"] == "Director")) do
      nil -> nil
      director -> director["name"]
    end
  end
  defp extract_director(_), do: nil

  defp extract_cast(nil), do: []
  defp extract_cast(%{"cast" => cast}) when is_list(cast) do
    cast
    |> Enum.take(10)
    |> Enum.map(& &1["name"])
  end
  defp extract_cast(_), do: []

  @doc """
  Creates or updates a movie from TMDB data.
  """
  def create_or_update_movie_from_tmdb(tmdb_id) do
    alias Smovie.Movies

    case get_movie_details(tmdb_id) do
      {:ok, tmdb_movie} ->
        attrs = tmdb_to_movie_attrs(tmdb_movie)

        case Movies.get_movie_by_tmdb_id(tmdb_id) do
          nil ->
            Movies.create_movie(attrs)

          existing_movie ->
            Movies.update_movie(existing_movie, attrs)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
