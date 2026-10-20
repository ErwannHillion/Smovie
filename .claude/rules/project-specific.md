# Smovie — Règles Spécifiques au Projet

## Ce qu'est Smovie

Un Letterboxd francophone. On note et on critique des **films et des séries**, jusqu'à
l'épisode, on suit des membres, on tient une liste à voir, et on partage tout ça en
messagerie privée ou de groupe.

Spécifications complètes : `file_for_claude/` (dossier de travail, non versionné).

## Architecture

### Contextes

| Contexte | Responsabilité |
|---|---|
| `Accounts` | comptes, sessions, profils, visibilités |
| `Catalog` | œuvres, genres, personnes, casting, notes externes, import TMDB |
| `Library` | ce que l'utilisateur fait des œuvres : notes, journal, watchlist, likes |
| `Reviews` | reviews, likes, commentaires |
| `Social` | abonnements, fil d'activité, notifications |
| `Messaging` | conversations, groupes, messages, partages |
| `Trending` | lecture des classements |
| `Search` | recherche locale et repli TMDB |

### La table `works`

Film, série, saison et épisode partagent **une seule table**, avec un discriminant
`kind` et une auto-référence `parent_id`. Conséquence : une note, une review, un like,
un partage ou une tendance s'appliquent indifféremment à un film ou à un épisode —
c'est le même code avec un `work_id` différent.

Ne jamais réintroduire une table par nature d'œuvre : la couche sociale devrait alors
être écrite quatre fois, ou reposer sur une clé polymorphe sans intégrité référentielle.

### La note

- L'utilisateur voit des **demi-étoiles, de ½★ à 5★**.
- La base stocke un **entier de 1 à 10** (le nombre de demi-étoiles).
- Jamais de flottant : pas d'arrondi parasite, agrégation exacte.
- La note affichée est une **moyenne bayésienne** (voir `05-algorithmes`), jamais la
  moyenne brute, qui placerait un film noté une fois en tête du classement.

### Trois notes, trois couleurs, jamais mélangées

| Note | Source | Couleur |
|---|---|---|
| Smovie | la communauté | violet `#a888f7` |
| Presse | IMDb, Metacritic, Rotten Tomatoes via OMDb | ambre `#f0a02e` |
| TMDB | public TMDB, en repli quand OMDb est coupé | gris |

L'étiquette doit toujours dire la source réelle. Afficher une note TMDB sous le mot
« presse » est un bug, pas un raccourci.

## Services externes

### TMDB — obligatoire

Catalogue et images. `TMDB_API_KEY` est requise au démarrage.

Le catalogue n'est pas aspiré : import **à la demande** au premier clic sur une fiche,
plus une synchro nocturne des sorties et des tendances. Tous les écrits en upsert sur
`(kind, tmdb_id)`, en **préservant** le slug et les compteurs communautaires — une
resynchro TMDB ne doit jamais écraser des données Smovie ni casser une URL partagée.

### OMDb — optionnel

Notes presse. Coupable par `OMDB_IS_ACTIVE=false` sans redéploiement. Quota de
**1 000 requêtes par jour** : un appel par œuvre tous les 7 jours maximum, déclenché à
la consultation, jamais en masse, dans une file Oban dédiée à concurrence 2.

## Internationalisation

**Français par défaut, anglais disponible.** Aucune chaîne visible en dur : tout passe
par Gettext dès la première ligne, y compris dans les composants fonctionnels.

- `SmovieWeb.Plugs.Locale` résout : préférence du compte → cookie → `accept-language` → `fr`
- `Gettext.put_locale/2` dans le `on_mount` LiveView, sinon les LiveViews rendent en
  langue par défaut quoi qu'il arrive
- Les formats de date et de nombre suivent la locale (`4,4` en français, `4.4` en anglais)

## Mobile-first

Contrainte transverse, posée avant la première ligne de HEEx.

1. Tout style s'écrit d'abord pour l'écran étroit (~360 px) ; le desktop passe par
   `sm:`, `md:`, `lg:`. **Aucune classe desktop sans équivalent mobile.**
2. Navigation : barre basse fixe de 5 entrées jusqu'à `md:`, barre haute au-delà. La
   barre basse réserve `env(safe-area-inset-bottom)`.
3. Grilles d'affiches : 3 colonnes par défaut, `sm:4`, `md:6`, `lg:8`.
4. Cibles tactiles ≥ 44 px, en particulier le sélecteur d'étoiles — un champ unique
   glissable, pas dix petits boutons.
5. Affiches servies par TMDB avec `srcset` (`w185`, `w342`, `w500`) et `loading="lazy"`.
6. Tout écran doit être utilisable à 360 px de large **sans scroll horizontal**.

## Temps réel

| Canal PubSub | Émis par | Consommé par |
|---|---|---|
| `conversation:<id>` | `Messaging.send_message/3` | `MessagingLive.Show` |
| `user:<id>:inbox` | messagerie, notifications | layout (badges) |
| `work:<id>:ratings` | `Library.rate_work/3` | `WorkLive.Show` |

`SmovieWeb.Presence` porte `presence:online` et `presence:conversation:<id>`.

## Variables d'environnement

### Obligatoires

- `SECRET_KEY_BASE`, `DATABASE_URL` (production)
- `TMDB_API_KEY`

### Optionnelles

- `OMDB_IS_ACTIVE` (défaut `false`), `OMDB_API_KEY`, `OMDB_DAILY_QUOTA` (défaut 1000)
- `TMDB_LANGUAGE` (défaut `fr-FR`), `TMDB_REGION` (défaut `FR`)
- `TRENDING_WINDOW_DAYS` (défaut 7), `TRENDING_MIN_VOTES` (défaut 3)
- `RATINGS_PRIOR_VOTES` (défaut 20), `POPULAR_REVIEWS_LIMIT` (défaut 5)

## CI

`mix format --check-formatted` → `mix credo --strict` → `mix sobelow --exit` →
`mix test`, plus le contrôle de la nomenclature `SMOVIE-XXX` et l'absence de référence
à un assistant IA dans les messages de commit.
