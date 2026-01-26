defmodule Smovie.Movies.Movie do
  use Ecto.Schema
  import Ecto.Changeset

  schema "movies" do
    field :tmdb_id, :integer
    field :title, :string
    field :original_title, :string
    field :overview, :string
    field :release_date, :date
    field :poster_path, :string
    field :backdrop_path, :string
    field :vote_average, :float
    field :vote_count, :integer
    field :runtime, :integer
    field :genres, {:array, :string}
    field :director, :string
    field :cast, {:array, :string}

    has_many :user_movies, Smovie.Movies.UserMovie

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(movie, attrs) do
    movie
    |> cast(attrs, [
      :tmdb_id,
      :title,
      :original_title,
      :overview,
      :release_date,
      :poster_path,
      :backdrop_path,
      :vote_average,
      :vote_count,
      :runtime,
      :genres,
      :director,
      :cast
    ])
    |> validate_required([:tmdb_id, :title])
    |> unique_constraint(:tmdb_id)
  end

  def poster_url(%__MODULE__{poster_path: nil}), do: nil
  def poster_url(%__MODULE__{poster_path: path}), do: "https://image.tmdb.org/t/p/w500#{path}"

  def backdrop_url(%__MODULE__{backdrop_path: nil}), do: nil
  def backdrop_url(%__MODULE__{backdrop_path: path}), do: "https://image.tmdb.org/t/p/w1280#{path}"

  def release_year(%__MODULE__{release_date: nil}), do: nil
  def release_year(%__MODULE__{release_date: date}), do: date.year

  def genre_names(%__MODULE__{genres: nil}), do: []
  def genre_names(%__MODULE__{genres: genres}), do: genres
end
