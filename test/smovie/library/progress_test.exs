defmodule Smovie.Library.ProgressTest do
  use Smovie.DataCase, async: true

  import Smovie.AccountsFixtures
  import Smovie.CatalogFixtures

  alias Smovie.Accounts.Scope
  alias Smovie.Library

  setup do
    user = user_fixture()
    show = tv_show_fixture()
    s1 = season_fixture(show, %{season_number: 1, title: "S1"})
    s2 = season_fixture(show, %{season_number: 2, title: "S2"})
    for n <- 1..3, do: episode_fixture(s1, %{episode_number: n, title: "S1E#{n}"})
    for n <- 1..2, do: episode_fixture(s2, %{episode_number: n, title: "S2E#{n}"})

    %{scope: Scope.for_user(user), show: show, s1: s1, s2: s2}
  end

  test "season_progress/2 rend les deux chiffres", %{scope: scope, s1: s1} do
    # « 7 vus » seul ne dit rien, et le total seul ne dit pas ou on en est.
    assert Library.season_progress(scope, s1) == %{watched: 0, total: 3}
  end

  test "compte les episodes vus", %{scope: scope, s1: s1} do
    [premier | _] = Smovie.Catalog.list_episodes(s1)
    Library.mark_watched(scope, premier)

    assert Library.season_progress(scope, s1) == %{watched: 1, total: 3}
  end

  test "un re-visionnage ne compte qu'une fois", %{scope: scope, s1: s1} do
    [premier | _] = Smovie.Catalog.list_episodes(s1)
    Library.mark_watched(scope, premier, watched_on: ~D[2024-01-10])
    Library.mark_watched(scope, premier, watched_on: ~D[2025-06-02])

    assert Library.season_progress(scope, s1).watched == 1
  end

  test "un visiteur voit le total sans progression", %{s1: s1} do
    assert Library.season_progress(nil, s1) == %{watched: 0, total: 3}
  end

  test "season_progress_by_id/2 couvre toute la serie en une requete", %{
    scope: scope,
    s1: s1,
    s2: s2
  } do
    [premier | _] = Smovie.Catalog.list_episodes(s1)
    Library.mark_watched(scope, premier)

    progress = Library.season_progress_by_id(scope, [s1, s2])

    assert progress[s1.id] == %{watched: 1, total: 3}
    assert progress[s2.id] == %{watched: 0, total: 2}
  end

  test "show_progress/2 cumule les saisons", %{scope: scope, show: show, s1: s1} do
    [premier | _] = Smovie.Catalog.list_episodes(s1)
    Library.mark_watched(scope, premier)

    assert Library.show_progress(scope, show) == %{watched: 1, total: 5}
  end
end
