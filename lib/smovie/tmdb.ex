defmodule Smovie.TMDB do
  @api_key "3b27f2809e11b60591c81a8eb4014c35"
  @base_url "https://api.themoviedb.org/3"

  def search_movie(query) do
    url = "#{@base_url}/search/movie?api_key=#{@api_key}&query=#{URI.encode(query)}"

    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "Error: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  def get_movie_details(movie_id) do
    url = "#{@base_url}/movie/#{movie_id}?api_key=#{@api_key}"

    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "Error: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end
end
