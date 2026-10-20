defmodule Smovie.Library.StatsTest do
  use Smovie.DataCase, async: true

  import Smovie.AccountsFixtures
  import Smovie.CatalogFixtures
  import Smovie.LibraryFixtures

  alias Smovie.Accounts.Scope
  alias Smovie.Catalog
  alias Smovie.Library

  setup do
    user = user_fixture()
    %{user: user, scope: Scope.for_user(user)}
  end

  test "average_rating/1 rend nil sans note", %{user: user} do
    assert Library.average_rating(user) == nil
  end

  test "average_rating/1 calcule la moyenne", %{user: user} do
    rate(user, movie_fixture(%{title: "A"}), 8)
    rate(user, movie_fixture(%{title: "B"}), 10)

    assert Library.average_rating(user) == 9.0
  end

  test "favourite_genres/2 ne compte que ce qui est bien note", %{user: user} do
    # Compter tous les genres vus decrirait ce qu'on regarde, pas ce qu'on
    # aime — et les deux different souvent.
    aime = movie_fixture(%{title: "Aime"})
    subi = movie_fixture(%{title: "Subi"})
    [sf] = Catalog.upsert_genres([%{tmdb_id: 878, name: "Science-Fiction"}])
    [comedie] = Catalog.upsert_genres([%{tmdb_id: 35, name: "Comedie"}])
    Catalog.put_work_genres(aime, [sf])
    Catalog.put_work_genres(subi, [comedie])

    rate(user, aime, 9)
    rate(user, subi, 3)

    assert Library.favourite_genres(user) == [{"Science-Fiction", 1}]
  end

  test "favourite_directors/2 exige un seuil plus eleve", %{user: user} do
    # On peut aimer un genre par habitude ; on ne cite un realisateur que pour
    # ses reussites.
    bon = movie_fixture(%{title: "Bon"})
    moyen = movie_fixture(%{title: "Moyen"})

    for {work, note} <- [{bon, 9}, {moyen, 7}] do
      Catalog.put_work_credits(work, [
        %{
          person: %{tmdb_id: 137_427, name: "Denis Villeneuve"},
          kind: :crew,
          job: "Director",
          department: "Directing",
          character: nil,
          display_order: nil
        }
      ])

      rate(user, work, note)
    end

    assert Library.favourite_directors(user) == [{"Denis Villeneuve", 1}]
  end

  test "rewatch_count/1 compte les oeuvres revues", %{user: user, scope: scope} do
    movie = movie_fixture()
    Library.mark_watched(scope, movie, watched_on: ~D[2024-01-10])
    Library.mark_watched(scope, movie, watched_on: ~D[2025-06-02])

    assert Library.rewatch_count(user) == 1
  end

  test "rewatch_count/1 ignore une oeuvre vue une fois", %{user: user, scope: scope} do
    Library.mark_watched(scope, movie_fixture())

    assert Library.rewatch_count(user) == 0
  end
end
