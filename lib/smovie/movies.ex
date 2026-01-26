defmodule Smovie.Movies do
  @moduledoc """
  The Movies context.
  """

  import Ecto.Query, warn: false
  alias Smovie.Repo

  alias Smovie.Movies.{Movie, UserMovie}

  @doc """
  Returns the list of movies.

  ## Examples

      iex> list_movies()
      [%Movie{}, ...]

  """
  def list_movies do
    Repo.all(Movie)
  end

  @doc """
  Gets a single movie.

  Raises `Ecto.NoResultsError` if the Movie does not exist.

  ## Examples

      iex> get_movie!(123)
      %Movie{}

      iex> get_movie!(456)
      ** (Ecto.NoResultsError)

  """
  def get_movie!(id), do: Repo.get!(Movie, id)

  @doc """
  Gets a movie by TMDB ID.

  ## Examples

      iex> get_movie_by_tmdb_id(123)
      %Movie{}

      iex> get_movie_by_tmdb_id(456)
      nil

  """
  def get_movie_by_tmdb_id(tmdb_id) do
    Repo.get_by(Movie, tmdb_id: tmdb_id)
  end

  @doc """
  Creates a movie.

  ## Examples

      iex> create_movie(%{field: value})
      {:ok, %Movie{}}

      iex> create_movie(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_movie(attrs \\ %{}) do
    %Movie{}
    |> Movie.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a movie.

  ## Examples

      iex> update_movie(movie, %{field: new_value})
      {:ok, %Movie{}}

      iex> update_movie(movie, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_movie(%Movie{} = movie, attrs) do
    movie
    |> Movie.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a movie.

  ## Examples

      iex> delete_movie(movie)
      {:ok, %Movie{}}

      iex> delete_movie(movie)
      {:error, %Ecto.Changeset{}}

  """
  def delete_movie(%Movie{} = movie) do
    Repo.delete(movie)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking movie changes.

  ## Examples

      iex> change_movie(movie)
      %Ecto.Changeset{data: %Movie{}}

  """
  def change_movie(%Movie{} = movie, attrs \\ %{}) do
    Movie.changeset(movie, attrs)
  end

  # UserMovie functions

  @doc """
  Gets a user movie by user and movie.
  """
  def get_user_movie(user_id, movie_id) do
    Repo.get_by(UserMovie, user_id: user_id, movie_id: movie_id)
  end

  @doc """
  Creates a user movie.
  """
  def create_user_movie(attrs \\ %{}) do
    %UserMovie{}
    |> UserMovie.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user movie.
  """
  def update_user_movie(%UserMovie{} = user_movie, attrs) do
    user_movie
    |> UserMovie.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user movie.
  """
  def delete_user_movie(%UserMovie{} = user_movie) do
    Repo.delete(user_movie)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user movie changes.

  ## Examples

      iex> change_user_movie(user_movie)
      %Ecto.Changeset{data: %UserMovie{}}

  """
  def change_user_movie(%UserMovie{} = user_movie, attrs \\ %{}) do
    UserMovie.changeset(user_movie, attrs)
  end

  @doc """
  Gets watched movies for a user.
  """
  def get_watched_movies(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)

    query =
      from um in UserMovie,
        join: m in Movie,
        on: um.movie_id == m.id,
        where: um.user_id == ^user_id and um.status == "watched",
        order_by: [desc: um.watched_at],
        select: {um, m},
        limit: ^limit,
        offset: ^offset

    Repo.all(query)
  end

  @doc """
  Gets watchlist movies for a user.
  """
  def get_watchlist_movies(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)

    query =
      from um in UserMovie,
        join: m in Movie,
        on: um.movie_id == m.id,
        where: um.user_id == ^user_id and um.status == "watchlist",
        order_by: [desc: um.inserted_at],
        select: {um, m},
        limit: ^limit,
        offset: ^offset

    Repo.all(query)
  end

  @doc """
  Gets recent watched movies across all users.
  """
  def get_recent_watched_movies(opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    query =
      from um in UserMovie,
        join: m in Movie,
        on: um.movie_id == m.id,
        join: u in Smovie.Accounts.User,
        on: um.user_id == u.id,
        where: um.status == "watched",
        order_by: [desc: um.watched_at],
        select: {um, m, u},
        limit: ^limit,
        offset: ^offset

    Repo.all(query)
  end

  @doc """
  Gets recent watched movies from followed users.
  """
  def get_followed_users_watched_movies(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    # Get IDs of users that the current user is following
    followed_ids = Smovie.Accounts.get_following_ids(user_id)

    if followed_ids == [] do
      []
    else
      query =
        from um in UserMovie,
          join: m in Movie,
          on: um.movie_id == m.id,
          join: u in Smovie.Accounts.User,
          on: um.user_id == u.id,
          where: um.status == "watched" and um.user_id in ^followed_ids,
          order_by: [desc: um.watched_at],
          select: {um, m, u},
          limit: ^limit,
          offset: ^offset

      Repo.all(query)
    end
  end

  @doc """
  Gets movie reviews/ratings from all users for a specific movie.
  """
  def get_movie_reviews(movie_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    query =
      from um in UserMovie,
        join: u in Smovie.Accounts.User,
        on: um.user_id == u.id,
        where: um.movie_id == ^movie_id and um.status == "watched",
        order_by: [desc: um.watched_at],
        select: {um, u},
        limit: ^limit,
        offset: ^offset

    Repo.all(query)
  end

  @doc """
  Gets average rating for a movie from site users.
  """
  def get_movie_average_rating(movie_id) do
    query =
      from um in UserMovie,
        where: um.movie_id == ^movie_id and um.status == "watched" and not is_nil(um.rating),
        select: %{
          average: avg(um.rating),
          count: count(um.id)
        }

    Repo.one(query)
  end

  @doc """
  Searches movies by title.
  """
  def search_movies(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    search_query =
      from m in Movie,
        where: ilike(m.title, ^"%#{query}%") or ilike(m.original_title, ^"%#{query}%"),
        order_by: [desc: m.vote_average],
        limit: ^limit,
        offset: ^offset

    Repo.all(search_query)
  end

  @doc """
  Adds or updates a user movie rating/review.
  """
  def rate_movie(user_id, movie_id, attrs) do
    case get_user_movie(user_id, movie_id) do
      nil ->
        create_user_movie(
          Map.merge(attrs, %{
            user_id: user_id,
            movie_id: movie_id,
            status: "watched",
            watched_at: DateTime.utc_now()
          })
        )

      user_movie ->
        update_user_movie(user_movie, attrs)
    end
  end

  @doc """
  Adds a movie to watchlist.
  """
  def add_to_watchlist(user_id, movie_id) do
    case get_user_movie(user_id, movie_id) do
      nil ->
        create_user_movie(%{
          user_id: user_id,
          movie_id: movie_id,
          status: "watchlist"
        })

      user_movie ->
        update_user_movie(user_movie, %{status: "watchlist"})
    end
  end

  @doc """
  Marks a movie as watched.
  """
  def mark_as_watched(user_id, movie_id) do
    case get_user_movie(user_id, movie_id) do
      nil ->
        create_user_movie(%{
          user_id: user_id,
          movie_id: movie_id,
          status: "watched",
          watched_at: DateTime.utc_now()
        })

      user_movie ->
        update_user_movie(user_movie, %{
          status: "watched",
          watched_at: DateTime.utc_now()
        })
    end
  end

  # TMDB API integration

  @doc """
  Gets popular movies from TMDB API.
  """
  def get_popular_movies do
    case Smovie.TMDB.get_popular_movies() do
      {:ok, %{"results" => results}} -> {:ok, results}
      {:ok, data} -> {:ok, data}
      error -> error
    end
  end

  @doc """
  Searches movies via TMDB API.
  """
  def search_movies_tmdb(query, page) do
    Smovie.TMDB.search_movies(query, page: page)
  end

  @doc """
  Adds a movie to watchlist from TMDB ID.
  First creates the movie in DB if it doesn't exist.
  """
  def add_to_watchlist_from_tmdb(user_id, tmdb_id) do
    with {:ok, movie} <- get_or_create_from_tmdb(tmdb_id) do
      case get_user_movie(user_id, movie.id) do
        nil ->
          create_user_movie(%{
            user_id: user_id,
            movie_id: movie.id,
            status: "watchlist"
          })

        user_movie ->
          update_user_movie(user_movie, %{status: "watchlist"})
      end
    end
  end

  @doc """
  Marks a movie as watched from TMDB ID.
  First creates the movie in DB if it doesn't exist.
  """
  def mark_as_watched_from_tmdb(user_id, tmdb_id) when is_integer(tmdb_id) do
    with {:ok, movie} <- get_or_create_from_tmdb(tmdb_id) do
      case get_user_movie(user_id, movie.id) do
        nil ->
          create_user_movie(%{
            user_id: user_id,
            movie_id: movie.id,
            status: "watched",
            watched_at: DateTime.utc_now()
          })

        user_movie ->
          update_user_movie(user_movie, %{
            status: "watched",
            watched_at: DateTime.utc_now()
          })
      end
    end
  end

  defp get_or_create_from_tmdb(tmdb_id) do
    case get_movie_by_tmdb_id(tmdb_id) do
      nil ->
        Smovie.TMDB.create_or_update_movie_from_tmdb(tmdb_id)

      movie ->
        {:ok, movie}
    end
  end

  @doc """
  Marks a movie as watched with details (rating, review, watched_at).

  ## Examples

      iex> mark_as_watched_with_details(user_id, movie_id, %{rating: 8, review: "Great movie"})
      {:ok, %UserMovie{}}

      iex> mark_as_watched_with_details(user_id, movie_id, %{rating: 15})
      {:error, %Ecto.Changeset{}}

  """
  def mark_as_watched_with_details(user_id, movie_id, attrs) do
    # Vérifier si le film existe déjà dans la liste de l'utilisateur
    case get_user_movie(user_id, movie_id) do
      nil ->
        # Créer un nouveau UserMovie avec les détails
        %UserMovie{
          user_id: user_id,
          movie_id: movie_id,
          status: "watched"
        }
        |> UserMovie.changeset(attrs)
        |> Repo.insert()
      
      existing_user_movie ->
        # Mettre à jour l'existant
        existing_user_movie
        |> UserMovie.changeset(Map.put(attrs, "status", "watched"))
        |> Repo.update()
    end
  end
end
