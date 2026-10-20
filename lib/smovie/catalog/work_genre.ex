defmodule Smovie.Catalog.WorkGenre do
  @moduledoc "Jonction entre une oeuvre et un genre."
  use Ecto.Schema

  @primary_key false
  schema "work_genres" do
    belongs_to :work, Smovie.Catalog.Work
    belongs_to :genre, Smovie.Catalog.Genre
  end
end
