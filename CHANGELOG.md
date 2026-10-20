# Changelog

Toutes les modifications notables de ce projet sont documentées dans ce fichier.

Format : [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/).

## [Unreleased]

### Added
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

### Fixed
- L'application démarre sur un poste neuf sans fichier `.env`
- La clé API TMDB est lue au démarrage et non plus figée à la compilation
