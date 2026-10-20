defmodule Smovie.LibraryFixtures do
  @moduledoc "Fixtures de la bibliotheque."

  alias Smovie.Accounts.Scope
  alias Smovie.Library

  def rate(user, work, value) do
    {:ok, rating} = Library.rate_work(Scope.for_user(user), work, value)
    rating
  end
end
