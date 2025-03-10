defmodule Smovie.TMDB do
  # ici big effet de bord a voir
  @api_key Application.compile_env(:smovie, TMDB)[:api_key]
  # @api_key "3b27f2809e11b60591c81a8eb4014c35"
  @base_url "https://api.themoviedb.org/3"

  # make a search by query and return a list of film | default language FR
  def search_movie(query, language \\ "fr-FR") do
    url =
      "#{@base_url}/search/movie?api_key=#{@api_key}&query=#{URI.encode(query)}&language=#{language}"

    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "Error: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  # get the details of a movie by its id
  def get_movie_details(movie_id, language \\ "fr-FR") do
    url = "#{@base_url}/movie/#{movie_id}?api_key=#{@api_key}&language=#{language}"

    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "Error: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  # get the latest movies released in the last 7 days
  def get_latest_movies(language \\ "fr-FR") do
    url = "#{@base_url}/movie/now_playing?api_key=#{@api_key}&language=#{language}"

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
