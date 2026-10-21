# Smovie

Un Letterboxd francophone. On note et on critique des **films et des séries** —
jusqu'à l'épisode — on suit d'autres membres, on tient une liste à voir, et on partage
tout ça en messagerie privée ou de groupe.

Interface en **français** et en **anglais**, pensée **mobile d'abord**.

---

## Ce que fait l'application

### Noter

Une note va de **½★ à 5★ par demi-crans**. Elle s'applique indifféremment à un film,
une série, une saison ou un épisode : c'est la même mécanique partout, pas quatre
fonctionnalités parallèles.

Trois notes cohabitent sur une fiche, et ne sont **jamais mélangées** :

| Note | Source | Couleur |
|---|---|---|
| **Smovie** | moyenne bayésienne de la communauté | violet |
| **Presse** | IMDb, Metacritic, Rotten Tomatoes | ambre |
| **TMDB** | public TMDB, en repli | gris |

La moyenne est bayésienne, pas brute : un film noté 5★ par une seule personne ne doit
pas dépasser un film noté 4,6★ par huit cents.

### Découvrir

La page d'accueil enchaîne les nouveautés, les tendances de la semaine, ce qui plaît
aux comptes que vous suivez, les séries du moment et les reviews à la une.

Le classement des tendances combine le **volume d'activité récente**, la **qualité des
notes** et une **décote temporelle**, pour qu'un pic retombe au lieu de figer la page
jusqu'à la fin de la semaine.

### Critiquer

Une review par membre et par œuvre, likable et commentable, avec masquage des spoilers
et réglage de visibilité. Les cinq reviews les plus likées remontent sur chaque fiche,
et la page `/reviews` classe les plus populaires avec une décote d'ancienneté.

### Suivre les séries

Une série déplie ses saisons, une saison déplie ses épisodes, et chaque épisode se note
en un geste. La progression s'affiche par saison. Noter un épisode n'oblige pas à noter
la série.

### Partager

Messagerie privée et groupes. Un message peut porter une **carte film** ou une **carte
review** cliquable — la carte lit l'œuvre à l'affichage, donc la note qu'elle montre est
toujours celle d'aujourd'hui.

### Garder une trace

Watchlist triable et filtrable, journal de visionnage, et un profil qui récapitule :
films vus, séries suivies, reviews, répartition des notes, genres et réalisateurs de
prédilection, heures de visionnage.

---

## Prérequis

- **Elixir 1.19+** / **Erlang OTP 28+**
- **PostgreSQL 17** — le `docker-compose.yml` du dépôt en fournit un
- **Docker** (facultatif, si vous utilisez le compose plutôt qu'un PostgreSQL local)
- Un **identifiant TMDB**, gratuit : <https://www.themoviedb.org/settings/api>

  La page en propose deux, et rien n'indique lequel prendre. L'application accepte les
  deux et reconnaît lequel vous avez donné :

  | Valeur sur la page TMDB | Variable | Forme |
  |---|---|---|
  | **API Read Access Token** | `TMDB_ACCESS_TOKEN` | long jeton `eyJ…`, en-tête `Bearer` |
  | **API Key** | `TMDB_API_KEY` | 32 caractères hexadécimaux, paramètre `api_key` |

## Installation

```bash
# 1. Variables d'environnement
cp .env.example .env    # puis renseigner TMDB_API_KEY

# 2. Base de données
docker compose up -d

# 3. Dépendances, base et assets
mix setup

# 4. Démarrage
mix phx.server          # ou : iex -S mix phx.server
```

L'application écoute sur <http://localhost:4000>.

## Configuration

Toutes les variables se lisent dans `config/runtime.exs`, et **uniquement** là. Le code
applicatif passe par `Smovie.Config` — jamais `System.get_env/1`, jamais
`Application.get_env/2` en direct.

### Obligatoires

| Variable | Rôle |
|---|---|
| `TMDB_ACCESS_TOKEN` **ou** `TMDB_API_KEY` | catalogue, affiches, casting |
| `SECRET_KEY_BASE` | production uniquement — `mix phx.gen.secret` |
| `DATABASE_URL` | production uniquement |

### Principales options

| Variable | Défaut | Rôle |
|---|---|---|
| `OMDB_IS_ACTIVE` | `false` | active les notes presse |
| `OMDB_API_KEY` | — | requis si OMDb est actif |
| `OMDB_DAILY_QUOTA` | `1000` | quota journalier du palier gratuit |
| `TMDB_LANGUAGE` | `fr-FR` | langue des métadonnées |
| `TMDB_REGION` | `FR` | région des sorties en salle |
| `TRENDING_WINDOW_DAYS` | `7` | fenêtre de calcul des tendances |
| `TRENDING_MIN_VOTES` | `3` | seuil d'entrée au classement |
| `RATINGS_PRIOR_VOTES` | `20` | poids de l'a priori bayésien |
| `POPULAR_REVIEWS_LIMIT` | `5` | reviews populaires par fiche |
| `DEFAULT_LOCALE` | `fr` | langue par défaut |
| `LOCALES` | `fr,en` | langues disponibles |

Liste complète et commentée : `.env.example`.

## Services externes

### TMDB — obligatoire

Source du catalogue et des images. Le catalogue n'est pas aspiré : une œuvre est
importée **au premier clic sur sa fiche**, et une synchro nocturne récupère les sorties
et les tendances. Les affiches ne sont pas réhébergées, elles sont servies par TMDB avec
un `srcset` adapté à la taille d'écran.

### OMDb — optionnel

Notes presse IMDb, Metacritic et Rotten Tomatoes. Le palier gratuit plafonne à
**1 000 requêtes par jour** : un appel par œuvre tous les sept jours au maximum,
déclenché à la consultation et jamais en masse.

`OMDB_IS_ACTIVE=false` coupe le fournisseur sans redéploiement — l'application affiche
alors la note TMDB seule, sans erreur visible.

## Développement

```bash
mix setup              # dépendances, base, assets
mix phx.server         # serveur de développement
mix test               # suite de tests
mix quality            # mix format --check-formatted puis mix credo --strict
mix format             # formatage
mix ecto.reset         # recrée la base
```

### Qualité

`mix credo --strict` exécute dix checks écrits pour ce projet (`.credo/`), qui
interdisent notamment :

- `Repo.` dans un module LiveView — tout passe par un contexte ;
- `Application.get_env/2` hors de `Smovie.Config` ;
- `socket.assigns.x` — déstructurer dans la signature ;
- `true = expr` pour une autorisation — filtrer dans la tête de fonction ;
- HTTPoison et Poison — le projet utilise `Req` et `Jason`.

### Conventions

Les règles de contribution vivent dans `.claude/rules/` :

| Fichier | Sujet |
|---|---|
| `git-commits.md` | nomenclature `SMOVIE-XXX type(scope): description` |
| `pull-requests.md` | structure des PR, mises à jour obligatoires |
| `elixir-code.md` | autorisations par pattern match, anti-patterns |
| `configuration.md` | variables d'environnement, `Smovie.Config` |
| `database.md` | migrations, upserts, préchargements |
| `changelog.md` | tenue du `CHANGELOG.md` |
| `project-specific.md` | architecture Smovie, mobile-first, i18n |

Workflow : une branche par ticket, des commits découpés par couche, une PR, puis merge
dans `main`.

## Architecture

```
lib/smovie/
├── config.ex        seul point de lecture de la configuration
├── accounts/        comptes, sessions, profils, visibilités
├── catalog/         œuvres, genres, personnes, casting, import TMDB
├── library/         notes, journal de visionnage, watchlist, likes
├── reviews/         reviews, likes, commentaires
├── social/          abonnements, fil d'activité, notifications
├── messaging/       conversations, groupes, messages, partages
├── external/        clients TMDB et OMDb, derrière des comportements
└── workers/         jobs Oban : synchro, tendances, notifications
```

### La table `works`

Film, série, saison et épisode partagent **une seule table**, avec un discriminant
`kind` et une auto-référence `parent_id`.

C'est la décision structurante du projet. La couche sociale — note, review, like,
watchlist, partage, activité, notification, tendance — représente l'essentiel du code.
Avec une table par nature d'œuvre, il faudrait l'écrire quatre fois, ou reposer sur une
clé polymorphe sans intégrité référentielle. Avec `works`, « noter un épisode » n'est
pas une fonctionnalité : c'est le même code avec un `work_id` différent.

### Mobile-first

Tout style s'écrit d'abord pour un écran de 360 px ; le desktop arrive par les
breakpoints Tailwind. Navigation en barre basse jusqu'à `md:`, en barre haute au-delà.
Cibles tactiles d'au moins 44 px. Aucun écran ne doit déborder horizontalement à 360 px.

### Internationalisation

Français par défaut, anglais disponible. Aucune chaîne visible en dur : tout passe par
Gettext, y compris dans les composants fonctionnels. La locale se résout dans l'ordre
préférence du compte → cookie → `accept-language` → `fr`.

## Déploiement

### Image Docker

```bash
docker build -t smovie .
docker run --rm -p 4000:4000 \
  -e DATABASE_URL=ecto://user:pass@host/smovie_prod \
  -e SECRET_KEY_BASE=$(mix phx.gen.secret) \
  -e PHX_HOST=smovie.fr \
  -e TMDB_API_KEY=... \
  smovie
```

L'image est construite en deux étapes : la seconde ne contient ni Elixir, ni sources,
seulement la release et ses dépendances système. Elle tourne sans privilèges.

Les migrations se jouent séparément du démarrage, pour qu'un déploiement raté ne laisse
pas la base à moitié migrée sans que personne ne le voie :

```bash
docker run --rm -e DATABASE_URL=... smovie /app/bin/migrate
```

### Release locale

```bash
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix release
```

Variables requises en production : `DATABASE_URL`, `SECRET_KEY_BASE`, `PHX_HOST`,
`TMDB_API_KEY`, et `PHX_SERVER=true` si vous démarrez la release directement.

## Traitements de fond

Oban, avec quatre tâches planifiées :

| Fréquence | Tâche | Rôle |
|---|---|---|
| toutes les **6 h** | `SyncTrendingCatalogWorker` | sorties en salle, séries en cours, tendances de la semaine |
| toutes les **15 min** | `RefreshTrendingWorker` | `REFRESH MATERIALIZED VIEW CONCURRENTLY trending_works` |
| toutes les **heures** | `RefreshRatingStatsWorker` | moyenne de la plateforme, a priori bayésien |
| **dimanche 4 h 30** | `PurgeActivitiesWorker` | purge du fil au-delà de 90 jours |

Trois autres tâches ne sont pas planifiées : elles sont mises en file par l'usage —
`SyncWorkWorker` (fiche consultée dont la synchro a vieilli), `SyncSeasonsWorker`
(première ouverture d'une série), `FetchExternalRatingsWorker` (notes presse).

**Rien à lancer à la main.** Au démarrage, si le catalogue compte moins de 20 œuvres,
la synchronisation est mise en file immédiatement : une installation neuve se remplit
toute seule en quelques secondes. La tâche est idempotente — un redémarrage sur un
catalogue fourni ne déclenche aucun appel.

Pour la couper (tests, environnement hors-ligne) :

```elixir
config :smovie, :catalog, bootstrap_on_boot: false
```

## Intégration continue

`.github/workflows/elixir.yml`, sur chaque PR et sur `main` :

| Étape | Ce qu'elle vérifie |
|---|---|
| Nomenclature | préfixe `SMOVIE-XXX type(scope):` et absence de référence à un assistant |
| Qualité | `compile --warnings-as-errors`, `format`, `credo --strict`, `sobelow`, traductions à jour |
| Tests | la suite, **plus un `ecto.rollback --all` suivi d'un `ecto.migrate`** |

Le rollback complet vérifie que chaque migration sait revenir en arrière : une migration
irréversible ne se découvre qu'en production, et toujours au pire moment.
