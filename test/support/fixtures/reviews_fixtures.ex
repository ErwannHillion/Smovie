defmodule Smovie.ReviewsFixtures do
  @moduledoc "Fixtures des reviews."

  alias Smovie.Accounts.Scope
  alias Smovie.Reviews

  @body "Glazer filme l'horreur en hors-champ pendant cent cinq minutes, " <>
          "et c'est precisement ce qui rend le film insoutenable."

  def review_fixture(user, work, attrs \\ %{}) do
    {:ok, review} =
      Reviews.publish(
        Scope.for_user(user),
        work,
        Enum.into(attrs, %{"body" => @body})
      )

    review
  end

  def long_body, do: @body
end
