defmodule Smovie.Catalog.Work do
  @moduledoc """
  Une oeuvre : film, serie, saison ou episode.

  Les quatre natures partagent cette table, avec un discriminant `kind` et une
  auto-reference `parent_id`. C'est la decision structurante du projet : la
  couche sociale — note, review, like, watchlist, partage, activite,
  notification, tendance — s'ecrit une fois pour les quatre.

  Hierarchie : `movie` et `tv_show` n'ont pas de parent, `season` pointe sur un
  `tv_show`, `episode` sur une `season`. La base le garantit par contrainte,
  pas seulement le changeset.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias Smovie.Catalog.WorkKind

  @shared_fields [
    :tmdb_id,
    :imdb_id,
    :title,
    :original_title,
    :overview,
    :tagline,
    :release_date,
    :runtime,
    :poster_path,
    :backdrop_path,
    :original_language,
    :status,
    :adult,
    :tmdb_popularity,
    :tmdb_vote_average,
    :tmdb_vote_count,
    :synced_at
  ]

  schema "works" do
    field :kind, WorkKind
    field :tmdb_id, :integer
    field :imdb_id, :string
    field :slug, :string

    field :title, :string
    field :original_title, :string
    field :overview, :string
    field :tagline, :string

    field :release_date, :date
    field :runtime, :integer
    field :poster_path, :string
    field :backdrop_path, :string
    field :original_language, :string

    field :season_number, :integer
    field :episode_number, :integer
    field :episode_count, :integer
    field :season_count, :integer

    field :status, :string
    field :adult, :boolean, default: false

    field :tmdb_popularity, :decimal
    field :tmdb_vote_average, :decimal
    field :tmdb_vote_count, :integer

    field :smovie_rating_avg, :decimal
    field :smovie_rating_count, :integer, default: 0
    field :smovie_watch_count, :integer, default: 0
    field :smovie_review_count, :integer, default: 0

    field :synced_at, :utc_datetime

    belongs_to :parent, __MODULE__
    has_many :children, __MODULE__, foreign_key: :parent_id
    has_many :credits, Smovie.Catalog.Credit
    many_to_many :genres, Smovie.Catalog.Genre, join_through: Smovie.Catalog.WorkGenre

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset d'un film.
  """
  def movie_changeset(work, attrs) do
    work
    |> cast(attrs, [:slug | @shared_fields])
    |> put_change(:kind, :movie)
    |> validate_root()
  end

  @doc """
  Changeset d'une serie.
  """
  def tv_show_changeset(work, attrs) do
    work
    |> cast(attrs, [:slug, :season_count, :episode_count | @shared_fields])
    |> put_change(:kind, :tv_show)
    |> validate_root()
  end

  @doc """
  Changeset d'une saison, rattachee a une serie.
  """
  def season_changeset(work, attrs) do
    work
    |> cast(attrs, [:slug, :parent_id, :season_number, :episode_count | @shared_fields])
    |> put_change(:kind, :season)
    |> validate_required([:season_number])
    |> validate_child()
  end

  @doc """
  Changeset d'un episode, rattache a une saison.
  """
  def episode_changeset(work, attrs) do
    work
    |> cast(attrs, [:slug, :parent_id, :season_number, :episode_number | @shared_fields])
    |> put_change(:kind, :episode)
    |> validate_required([:season_number, :episode_number])
    |> validate_child()
  end

  @doc """
  Changeset generique, pour quand la nature vient des donnees.
  """
  def changeset(work, %{kind: kind} = attrs), do: changeset_for(kind, work, attrs)
  def changeset(work, %{"kind" => kind} = attrs), do: changeset_for(kind, work, attrs)

  defp changeset_for(kind, work, attrs) do
    case WorkKind.cast(kind) do
      {:ok, :movie} -> movie_changeset(work, attrs)
      {:ok, :tv_show} -> tv_show_changeset(work, attrs)
      {:ok, :season} -> season_changeset(work, attrs)
      {:ok, :episode} -> episode_changeset(work, attrs)
      :error -> work |> cast(attrs, []) |> add_error(:kind, "is invalid")
    end
  end

  defp validate_root(changeset) do
    changeset
    |> put_change(:parent_id, nil)
    |> validate_common()
  end

  defp validate_child(changeset) do
    changeset
    |> validate_required([:parent_id])
    |> foreign_key_constraint(:parent_id)
    |> validate_common()
  end

  defp validate_common(changeset) do
    changeset
    |> validate_required([:kind, :tmdb_id, :title, :slug])
    |> validate_length(:title, max: 300)
    |> validate_length(:slug, max: 160)
    |> validate_number(:runtime, greater_than_or_equal_to: 0)
    |> validate_number(:season_number, greater_than_or_equal_to: 0)
    |> validate_number(:episode_number, greater_than_or_equal_to: 0)
    |> unique_constraint([:kind, :tmdb_id])
    |> unique_constraint(:slug)
    |> unique_constraint([:parent_id, :season_number], name: :works_season_unique)
    |> unique_constraint([:parent_id, :episode_number], name: :works_episode_unique)
    |> check_constraint(:kind, name: :works_hierarchy, message: "hierarchie invalide")
    |> check_constraint(:season_number, name: :works_season_number)
    |> check_constraint(:episode_number, name: :works_episode_number)
  end

  @doc """
  Chemin public d'une oeuvre.

  Une saison et un episode n'ont pas d'adresse propre : ils vivent sous la
  page de leur saison, parce qu'on les consulte dans le contexte de la serie
  et jamais isolement.
  """
  def path(%__MODULE__{kind: :movie, slug: slug}), do: "/film/#{slug}"
  def path(%__MODULE__{kind: :tv_show, slug: slug}), do: "/serie/#{slug}"

  def path(%__MODULE__{kind: :season, season_number: number, parent: %__MODULE__{slug: slug}}),
    do: "/serie/#{slug}/saison/#{number}"

  def path(%__MODULE__{kind: :episode, season_number: number, parent: parent}),
    do: season_path(parent, number)

  defp season_path(%__MODULE__{parent: %__MODULE__{slug: slug}}, number),
    do: "/serie/#{slug}/saison/#{number}"

  defp season_path(_parent, _number), do: nil

  @doc """
  Annee de sortie, ou `nil`.
  """
  def year(%__MODULE__{release_date: %Date{year: year}}), do: year
  def year(%__MODULE__{}), do: nil

  @doc """
  Note Smovie en demi-etoiles, arrondie, ou `nil` sous le seuil de votes.

  Sous le seuil, une moyenne est plus trompeuse que le nombre brut de notes :
  mieux vaut ne rien afficher.
  """
  def smovie_half_stars(%__MODULE__{smovie_rating_avg: nil}, _min_votes), do: nil

  def smovie_half_stars(%__MODULE__{smovie_rating_count: count}, min_votes)
      when count < min_votes,
      do: nil

  def smovie_half_stars(%__MODULE__{smovie_rating_avg: average}, _min_votes) do
    average |> Decimal.round(0) |> Decimal.to_integer()
  end

  @doc """
  Note Smovie sur 5, en flottant, ou `nil`.
  """
  def smovie_out_of_five(%__MODULE__{smovie_rating_avg: nil}), do: nil

  def smovie_out_of_five(%__MODULE__{smovie_rating_avg: average}) do
    average |> Decimal.div(2) |> Decimal.to_float()
  end

  @doc """
  Note TMDB sur 10, en flottant, ou `nil`.
  """
  def tmdb_out_of_ten(%__MODULE__{tmdb_vote_average: nil}), do: nil
  def tmdb_out_of_ten(%__MODULE__{tmdb_vote_average: average}), do: Decimal.to_float(average)
end
