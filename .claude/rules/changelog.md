# Changelog Rules

## Objectif

Maintenir un suivi des fonctionnalités livrées pour préparer les releases.

## Format

Le fichier `CHANGELOG.md` se trouve à la racine du projet.

Format : [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/)

```markdown
# Changelog

Toutes les modifications notables de ce projet seront documentées dans ce fichier.

## [Unreleased]

### Added
- Nouvelle fonctionnalite X pour [contexte]
- Nouveau module Y pour gerer [cas d'usage]

### Changed
- Amélioration de Z pour [raison]
- Refactorisation de W pour [bénéfice]

### Fixed
- Correction du bug A dans [contexte]
- Résolution du problème B causé par [raison]

### Removed
- Suppression de la feature obsolète C

## [1.2.0] - 2025-01-15

### Added
- Fiches film et série avec note Smovie et note presse
- Notation des épisodes un par un

...
```

## Workflow

### Avant Chaque PR

**TOUJOURS** mettre à jour le `CHANGELOG.md` dans la section `[Unreleased]`.

```bash
# 1. Identifier les changements principaux de la PR
# 2. Les ajouter dans CHANGELOG.md sous [Unreleased]
# 3. Commit avec les autres changements
```

### Catégories

- **Added** : Nouvelles fonctionnalités
- **Changed** : Modifications de fonctionnalités existantes
- **Fixed** : Corrections de bugs
- **Removed** : Fonctionnalités supprimées
- **Deprecated** : Fonctionnalités dépréciées (à supprimer prochainement)
- **Security** : Corrections de sécurité

### Style

✅ **Bon** - Concis et orienté métier :
```markdown
### Added
- Notation des episodes un par un, avec progression par saison
- Note presse IMDb et Metacritic sur les fiches film et serie
- Partage d'un film ou d'une review dans une conversation

### Fixed
- Compteur de likes d'une review apres un retrait
- Moyenne Smovie des oeuvres ayant moins de trois notes
```

❌ **Mauvais** - Trop technique ou verbeux :
```markdown
### Added
- Ajout du champ rating_value smallint dans Smovie.Reviews.Review ligne 23 avec un CHECK BETWEEN 1 AND 10 pour stocker la note en demi-etoiles au moment de la publication via Reviews.publish/3 qui copie ratings.value
```

## Remaniement du Changelog

Si la section `[Unreleased]` devient trop longue ou verbeuse :
- Regrouper les changements similaires
- Simplifier les descriptions
- Supprimer les détails trop techniques

**Moment idéal** : Juste avant une release.

## Exemple Complet

```markdown
# Changelog

## [Unreleased]

### Added
- Watchlist avec tri par sortie, duree et note Smovie
- Notifications d'abonnement, de like et de commentaire
- Masquage des reviews a spoilers derriere un clic

### Changed
- Classement des tendances calcule sur une fenetre de sept jours
- Simplification du selecteur d'etoiles en un champ glissable

### Fixed
- Correction du tri des episodes au-dela du numero 9
- Fix de l'import TMDB des series sans date de premiere diffusion

## [1.5.0] - 2025-01-20

### Added
- Fiches film et serie avec note Smovie et note presse
- Import a la demande du catalogue TMDB

### Fixed
- Gestion des erreurs de quota OMDb

## [1.4.0] - 2025-01-10

...
```

## Intégration avec PRs

Le changelog peut être référencé dans le corps de la PR :

```markdown
## Résumé
Ajout de la notation des episodes et de la progression par saison.

## Changements
Voir CHANGELOG.md section [Unreleased]

## Test plan
- [ ] Noter trois episodes d'une saison
- [ ] Verifier la progression affichee sur la fiche serie
- [ ] Verifier que la note de la serie reste independante
```

## Notes

- Le changelog est un **document vivant**
- Il peut être remanié avant chaque release
- Il sert de base pour les notes de release
- Il aide à communiquer les changements aux utilisateurs
