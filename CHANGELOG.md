# Changelog

Toutes les modifications notables de ce projet sont documentées dans ce fichier.

Format : [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/).

## [Unreleased]

### Added
- `Smovie.Config`, point de lecture unique de la configuration applicative
- Oban pour les traitements de fond : synchronisation du catalogue, tendances,
  notifications ; quatre files dimensionnées par ce qu'elles appellent
- Cachex pour le cache des réponses TMDB et OMDb
- Flop pour la pagination et le tri des listes
- Content Security Policy avec nonce par requête, et Sobelow dans `mix quality`
- Règles de développement et dix checks Credo custom versionnés dans le dépôt
- Fichier `.credo.exs` : les dix checks s'exécutent enfin avec `mix credo --strict`
- Alias `mix quality` : vérification du formatage puis Credo en mode strict
- `.env.example` documentant toutes les variables, avec leurs valeurs par défaut

### Changed
- README décrivant le projet cible : fonctionnalités, configuration, architecture
- Elixir 1.19, Phoenix 1.8.15, LiveView 1.2, Gettext 1.0 et l'ensemble des dépendances
- Image PostgreSQL épinglée en 17, données dans un volume Docker nommé
- Nomenclature des tickets et des branches : `REALTIX-XXX` devient `SMOVIE-XXX`
- Règles du projet réécrites pour Smovie : contextes, table `works` unifiée,
  notation en demi-étoiles, TMDB et OMDb, internationalisation, mobile-first
- Toutes les variables d'environnement se lisent dans `config/runtime.exs`

### Removed
- LiveViews, contrôleur et contexte de l'ancienne version (2 265 lignes)
- Client TMDB, remplacé par `Smovie.External.TMDB` (SMOVIE-009)
- Migrations des tables `movies`, `user_movies` et `user_follows`, remplacées
  par la table `works` unifiée et les contextes `Library` et `Social`
- `Dockerfile.yml`, inutilisable : syntaxe GitHub Actions dans un Dockerfile et
  script `testbdd.sh` absent du dépôt
- Navigation du scaffold Phoenix dans le layout applicatif

### Fixed
- Le check Credo sur la lecture de configuration cherchait `:intranet` en dur et
  ne détectait donc rien ; il couvre `:smovie`, `fetch_env!/2` et `fetch_env/2`
- Un mode sudo expiré renvoie vers une reconnexion au lieu de sortir en 500
- L'application démarre sur un poste neuf sans fichier `.env`
- La clé API TMDB est lue au démarrage et non plus figée à la compilation
