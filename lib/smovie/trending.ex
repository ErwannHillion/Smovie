defmodule Smovie.Trending do
  @moduledoc """
  Lecture des classements.

  Les tendances sont precalculees dans une vue materialisee : l'accueil lit un
  `ORDER BY score DESC LIMIT 20` sur une table deja agregee, au lieu de
  recalculer quatre sous-requetes a chaque visite.
  """

  import Ecto.Query, warn: false

  alias Smovie.Accounts.Scope
  alias Smovie.Catalog.Work
  alias Smovie.Library.Rating
  alias Smovie.Repo
  alias Smovie.Social

  @doc """
  Oeuvres en tendance.
  """
  def list(opts \\ []) do
    kind = Keyword.get(opts, :kind, :movie)
    limit = Keyword.get(opts, :limit, 20)

    Repo.all(
      from w in Work,
        join: t in "trending_works",
        on: t.work_id == w.id,
        where: t.kind == ^Atom.to_string(kind),
        order_by: [desc: t.score],
        limit: ^limit
    )
  end

  @doc """
  L'oeuvre la plus en tendance, pour le heros de l'accueil.
  """
  def headline do
    case list(limit: 1) do
      [work] -> work
      [] -> nil
    end
  end

  @doc """
  Rafraichit la vue, sans bloquer les lecteurs.
  """
  def refresh do
    Repo.query!("REFRESH MATERIALIZED VIEW CONCURRENTLY trending_works", [], timeout: 60_000)
    :ok
  end

  @doc """
  Ce qui plait aux comptes suivis.

  Pas de vue materialisee ici : le resultat depend de qui regarde.

  Trois decisions. Une fenetre de trente jours, plus large que les tendances
  globales parce que le reseau d'une personne est moins actif. Un seuil de
  3,5 etoiles, parce qu'on veut une recommandation et pas un simple
  visionnage. Et l'exclusion de ce que le membre a deja note : lui remontrer
  ce qu'il connait n'apporte rien.
  """
  def popular_with_following(scope, opts \\ [])

  def popular_with_following(%Scope{user: %{id: user_id}} = scope, opts) do
    limit = Keyword.get(opts, :limit, 20)
    days = Keyword.get(opts, :days, 30)
    ids = Social.following_ids(scope)
    since = DateTime.add(DateTime.utc_now(), -days, :day)

    if ids == [] do
      []
    else
      deja_notees = from(mine in Rating, where: mine.user_id == ^user_id, select: mine.work_id)

      Repo.all(
        from w in Work,
          join: r in Rating,
          on: r.work_id == w.id,
          where: r.user_id in ^ids,
          where: r.rated_at > ^since,
          where: r.value >= 7,
          # Lui remontrer ce qu'il connait deja n'apporte rien.
          where: w.id not in subquery(deja_notees),
          group_by: w.id,
          # Deux avis concordants au minimum : avec un seul, le bloc se
          # remplirait de bruit.
          having: count(r.id) >= 2,
          order_by: [desc: count(r.id), desc: avg(r.value)],
          limit: ^limit
      )
    end
  end

  def popular_with_following(nil, _opts), do: []
end
