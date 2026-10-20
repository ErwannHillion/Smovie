defmodule Smovie.CatalogTest do
  use Smovie.DataCase, async: true

  import Smovie.CatalogFixtures

  alias Smovie.Catalog
  alias Smovie.Catalog.Work

  describe "hierarchie" do
    test "un film et une serie n'ont pas de parent" do
      assert movie_fixture().parent_id == nil
      assert tv_show_fixture().parent_id == nil
    end

    test "une saison pend d'une serie, un episode d'une saison" do
      show = tv_show_fixture()
      season = season_fixture(show)
      episode = episode_fixture(season)

      assert season.parent_id == show.id
      assert episode.parent_id == season.id
    end

    test "la base refuse un episode sans parent" do
      # La contrainte vit en base et pas seulement dans le changeset : un
      # episode orphelin serait impossible a rattacher apres coup.
      assert_raise Postgrex.Error, ~r/works_hierarchy/, fn ->
        Smovie.Repo.insert_all("works", [
          %{
            kind: "episode",
            tmdb_id: unique_tmdb_id(),
            slug: "orphelin",
            title: "Orphelin",
            season_number: 1,
            episode_number: 1,
            adult: false,
            smovie_rating_count: 0,
            smovie_watch_count: 0,
            smovie_review_count: 0,
            inserted_at: DateTime.utc_now(:second),
            updated_at: DateTime.utc_now(:second)
          }
        ])
      end
    end

    test "la base refuse un film avec un parent" do
      show = tv_show_fixture()

      assert_raise Postgrex.Error, ~r/works_hierarchy/, fn ->
        Smovie.Repo.insert_all("works", [
          %{
            kind: "movie",
            parent_id: show.id,
            tmdb_id: unique_tmdb_id(),
            slug: "film-avec-parent",
            title: "Film",
            adult: false,
            smovie_rating_count: 0,
            smovie_watch_count: 0,
            smovie_review_count: 0,
            inserted_at: DateTime.utc_now(:second),
            updated_at: DateTime.utc_now(:second)
          }
        ])
      end
    end

    test "supprimer une serie emporte ses saisons et ses episodes" do
      show = tv_show_fixture()
      season = season_fixture(show)
      episode = episode_fixture(season)

      Smovie.Repo.delete!(show)

      refute Smovie.Repo.get(Work, season.id)
      refute Smovie.Repo.get(Work, episode.id)
    end

    test "une serie n'a qu'une saison portant un numero donne" do
      show = tv_show_fixture()
      season_fixture(show, %{season_number: 1})

      assert {:error, changeset} =
               Catalog.upsert_work(%{
                 kind: :season,
                 parent_id: show.id,
                 tmdb_id: unique_tmdb_id(),
                 title: "Saison 1 bis",
                 season_number: 1
               })

      assert errors_on(changeset)[:parent_id] || errors_on(changeset)[:season_number]
    end
  end

  describe "changesets par nature" do
    test "refusent une nature inconnue" do
      assert {:error, changeset} =
               Catalog.upsert_work(%{kind: "documentaire", tmdb_id: 1, title: "X"})

      assert errors_on(changeset)[:kind]
    end

    test "un film ignore un parent qu'on tenterait de lui donner" do
      show = tv_show_fixture()

      {:ok, movie} =
        Catalog.upsert_work(%{
          kind: :movie,
          parent_id: show.id,
          tmdb_id: unique_tmdb_id(),
          title: "Film"
        })

      assert movie.parent_id == nil
    end

    test "une saison exige son numero" do
      show = tv_show_fixture()

      assert {:error, changeset} =
               Catalog.upsert_work(%{
                 kind: :season,
                 parent_id: show.id,
                 tmdb_id: unique_tmdb_id(),
                 title: "Saison"
               })

      assert errors_on(changeset)[:season_number]
    end
  end

  describe "upsert_work/1" do
    test "cree puis met a jour sur (kind, tmdb_id)" do
      tmdb_id = unique_tmdb_id()
      {:ok, first} = Catalog.upsert_work(%{kind: :movie, tmdb_id: tmdb_id, title: "Avant"})

      {:ok, second} =
        Catalog.upsert_work(%{kind: :movie, tmdb_id: tmdb_id, title: "Apres", runtime: 120})

      assert first.id == second.id
      assert second.title == "Apres"
      assert second.runtime == 120
    end

    test "un film et une serie peuvent partager un identifiant TMDB" do
      # Les espaces d'identifiants TMDB sont distincts par type.
      tmdb_id = unique_tmdb_id()

      assert {:ok, _} = Catalog.upsert_work(%{kind: :movie, tmdb_id: tmdb_id, title: "Film"})
      assert {:ok, _} = Catalog.upsert_work(%{kind: :tv_show, tmdb_id: tmdb_id, title: "Serie"})
    end

    test "preserve le slug a la resynchronisation" do
      # Une URL partagee dans une review ou une conversation ne doit pas
      # cesser de fonctionner parce qu'un titre a change en amont.
      movie = movie_fixture(%{title: "Titre initial"})

      {:ok, resynced} =
        Catalog.upsert_work(%{kind: :movie, tmdb_id: movie.tmdb_id, title: "Titre corrige"})

      assert resynced.slug == movie.slug
      assert resynced.title == "Titre corrige"
    end

    test "preserve les compteurs communautaires a la resynchronisation" do
      movie = movie_fixture()

      Smovie.Repo.update_all(
        from(w in Work, where: w.id == ^movie.id),
        set: [smovie_rating_count: 42, smovie_rating_avg: Decimal.new("8.40")]
      )

      {:ok, resynced} =
        Catalog.upsert_work(%{kind: :movie, tmdb_id: movie.tmdb_id, title: movie.title})

      assert resynced.smovie_rating_count == 42
      assert Decimal.equal?(resynced.smovie_rating_avg, Decimal.new("8.40"))
    end

    test "desambiguise deux films homonymes de la meme annee" do
      a = movie_fixture(%{title: "Carrie", release_date: ~D[1976-11-03]})
      b = movie_fixture(%{title: "Carrie", release_date: ~D[1976-11-03]})

      assert a.slug == "carrie-1976"
      assert b.slug == "carrie-1976-2"
    end
  end

  describe "lecture" do
    test "get_movie_by_slug/1 ne renvoie pas une serie" do
      show = tv_show_fixture()

      assert Catalog.get_movie_by_slug(show.slug) == nil
      assert Catalog.get_tv_show_by_slug(show.slug).id == show.id
    end

    test "list_seasons/1 trie par numero" do
      show = tv_show_fixture()
      season_fixture(show, %{season_number: 2, title: "Saison 2"})
      season_fixture(show, %{season_number: 1, title: "Saison 1"})

      assert [%{season_number: 1}, %{season_number: 2}] = Catalog.list_seasons(show)
    end

    test "list_episodes/1 trie par numero au-dela de dix" do
      # Un tri lexicographique placerait l'episode 10 avant le 2.
      show = tv_show_fixture()
      season = season_fixture(show)
      for n <- [10, 2, 1], do: episode_fixture(season, %{episode_number: n, title: "E#{n}"})

      assert Enum.map(Catalog.list_episodes(season), & &1.episode_number) == [1, 2, 10]
    end

    test "list_recent_releases/2 ecarte les sorties trop anciennes" do
      recent = movie_fixture(%{release_date: Date.add(Date.utc_today(), -10)})
      movie_fixture(%{release_date: ~D[1999-03-31], title: "Matrix"})

      ids = Catalog.list_recent_releases(:movie) |> Enum.map(& &1.id)

      assert recent.id in ids
      assert length(ids) == 1
    end

    test "list_recent_releases/2 inclut les sorties imminentes" do
      soon = movie_fixture(%{release_date: Date.add(Date.utc_today(), 3)})

      assert soon.id in Enum.map(Catalog.list_recent_releases(:movie), & &1.id)
    end
  end

  describe "search/2" do
    test "trouve par titre francais" do
      movie = movie_fixture(%{title: "Le Comte de Monte-Cristo"})

      assert [found] = Catalog.search("monte-cristo")
      assert found.id == movie.id
    end

    test "trouve par titre original" do
      movie = movie_fixture(%{title: "Pauvres créatures", original_title: "Poor Things"})

      assert [found] = Catalog.search("poor things")
      assert found.id == movie.id
    end

    test "tolere une faute de frappe par repli trigram" do
      # Une faute ne doit pas produire une page vide alors que l'oeuvre est la.
      movie = movie_fixture(%{title: "Severance", original_title: "Severance"})

      assert [found] = Catalog.search("severence")
      assert found.id == movie.id
    end

    test "ne cherche pas sous trois caracteres" do
      movie_fixture(%{title: "Dune"})

      assert Catalog.search("du") == []
      assert Catalog.search("") == []
    end

    test "ignore ce qui n'est pas une chaine" do
      assert Catalog.search(nil) == []
      assert Catalog.search(42) == []
    end

    test "ne renvoie ni saisons ni episodes par defaut" do
      show = tv_show_fixture(%{title: "Severance"})
      season = season_fixture(show, %{title: "Severance saison 1"})
      episode_fixture(season, %{title: "Severance episode"})

      ids = Catalog.search("severance") |> Enum.map(& &1.id)

      assert show.id in ids
      assert length(ids) == 1
    end
  end

  describe "stale?/1" do
    test "une oeuvre jamais synchronisee l'est" do
      assert Catalog.stale?(%Work{synced_at: nil})
    end

    test "une sortie recente se rafraichit au bout de sept jours" do
      work = %Work{release_date: Date.utc_today(), synced_at: days_ago(8)}

      assert Catalog.stale?(work)
      refute Catalog.stale?(%{work | synced_at: days_ago(3)})
    end

    test "une sortie ancienne attend trente jours" do
      # Au-dela de deux ans, les metadonnees ne bougent plus.
      work = %Work{release_date: ~D[2010-01-01], synced_at: days_ago(20)}

      refute Catalog.stale?(work)
      assert Catalog.stale?(%{work | synced_at: days_ago(31)})
    end
  end

  describe "Work.path/1" do
    test "donne une adresse par nature" do
      movie = movie_fixture()
      show = tv_show_fixture()
      season = season_fixture(show, %{season_number: 2})

      assert Work.path(movie) == "/film/#{movie.slug}"
      assert Work.path(show) == "/serie/#{show.slug}"
      assert Work.path(%{season | parent: show}) == "/serie/#{show.slug}/saison/2"
    end
  end

  describe "Work.smovie_half_stars/2" do
    test "ne renvoie rien sous le seuil de votes" do
      work = %Work{smovie_rating_avg: Decimal.new("9.00"), smovie_rating_count: 1}

      assert Work.smovie_half_stars(work, 3) == nil
    end

    test "renvoie la note arrondie au-dela du seuil" do
      work = %Work{smovie_rating_avg: Decimal.new("8.60"), smovie_rating_count: 50}

      assert Work.smovie_half_stars(work, 3) == 9
    end
  end

  defp days_ago(days),
    do: DateTime.add(DateTime.utc_now(), -days, :day) |> DateTime.truncate(:second)
end
