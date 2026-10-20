defmodule Smovie.Repo.Migrations.CreateTrendingWorks do
  use Ecto.Migration

  @moduledoc """
  Classement des tendances, en vue materialisee.

  Trois ingredients : du volume recent, de la qualite, et une decote
  temporelle pour qu'un pic retombe. Sans la decote, le classement de la
  semaine se figerait des le lundi.

  Les constantes sont ecrites en dur dans la definition : changer la fenetre
  de calcul demande une migration qui redefinit la vue, ce qui est le bon
  niveau de ceremonie pour une formule de classement.
  """

  def up do
    execute """
    CREATE MATERIALIZED VIEW trending_works AS
    WITH notes AS (
      SELECT work_id, COUNT(*) AS n, AVG(value) AS moyenne, MAX(rated_at) AS derniere
        FROM ratings
       WHERE rated_at > now() - interval '7 days'
       GROUP BY work_id
    ),
    seances AS (
      SELECT work_id, COUNT(*) AS n, MAX(inserted_at) AS derniere
        FROM watch_entries
       WHERE inserted_at > now() - interval '7 days'
       GROUP BY work_id
    ),
    critiques AS (
      SELECT work_id, COUNT(*) AS n, COALESCE(SUM(likes_count), 0) AS likes,
             MAX(published_at) AS derniere
        FROM reviews
       WHERE published_at > now() - interval '7 days' AND visibility = 'public'
       GROUP BY work_id
    ),
    envies AS (
      SELECT work_id, COUNT(*) AS n, MAX(inserted_at) AS derniere
        FROM watchlist_items
       WHERE inserted_at > now() - interval '7 days'
       GROUP BY work_id
    ),
    agrege AS (
      SELECT w.id AS work_id,
             w.kind,
             COALESCE(no.n, 0) AS ratings_count,
             COALESCE(no.moyenne, 5.5) AS recent_average,
             COALESCE(no.n, 0) + COALESCE(se.n, 0) + COALESCE(cr.n, 0) + COALESCE(en.n, 0)
               AS signals_count,
             -- Une review pese 2 : ecrire un texte est un signal plus fort
             -- qu'un clic sur une etoile.
             1.0 * COALESCE(no.n, 0)
               + 0.5 * COALESCE(se.n, 0)
               + 2.0 * COALESCE(cr.n, 0)
               + 0.25 * COALESCE(cr.likes, 0)
               + 0.75 * COALESCE(en.n, 0) AS velocite,
             GREATEST(
               COALESCE(no.derniere, 'epoch'::timestamptz),
               COALESCE(se.derniere, 'epoch'::timestamptz),
               COALESCE(cr.derniere, 'epoch'::timestamptz),
               COALESCE(en.derniere, 'epoch'::timestamptz)
             ) AS last_activity_at
        FROM works w
        LEFT JOIN notes no ON no.work_id = w.id
        LEFT JOIN seances se ON se.work_id = w.id
        LEFT JOIN critiques cr ON cr.work_id = w.id
        LEFT JOIN envies en ON en.work_id = w.id
       WHERE w.kind IN ('movie', 'tv_show')
    )
    SELECT work_id,
           kind,
           ratings_count,
           recent_average,
           signals_count,
           last_activity_at,
           (
             -- Exposant 0,8 : amortit l'ecart entre un film a 500 notes et un
             -- film a 50, sinon seuls les blockbusters apparaissent.
             POWER(velocite, 0.8)
             -- Qualite recentree et bornee : une oeuvre detestee reste visible,
             -- c'est aussi une tendance, mais elle ne peut pas dominer.
             * LEAST(1.00, GREATEST(0.10, 0.55 + 0.45 * ((recent_average - 5.5) / 4.5)))
             -- Fraicheur : sans elle, le classement se fige des le lundi.
             * (1.0 / (1.0 + EXTRACT(EPOCH FROM (now() - last_activity_at)) / 259200.0))
           )::numeric(12,4) AS score
      FROM agrege
     WHERE signals_count >= 3
    """

    # Index unique obligatoire pour REFRESH ... CONCURRENTLY, qui rafraichit
    # sans bloquer les lecteurs.
    create unique_index(:trending_works, [:work_id])
    create index(:trending_works, [:kind, :score])
  end

  def down do
    execute "DROP MATERIALIZED VIEW trending_works"
  end
end
