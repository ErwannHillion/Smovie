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
- Nouvelle fonctionnalité X pour [contexte]
- Nouveau module Y pour gérer [cas d'usage]

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
- Authentification Microsoft avec cookie persistant
- Gestion des réservations de salles avec calendrier

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
- Authentification Microsoft avec cookie persistant (60 jours)
- Retry automatique de connexion dans client lourd
- Widget calendrier dynamique sur page d'accueil

### Fixed
- Affichage des accents dans notifications de réservation
- Gestion des participants non-inscrits aux réunions
```

❌ **Mauvais** - Trop technique ou verbeux :
```markdown
### Added
- Ajout du paramètre remember_me=true dans IntranetWeb.AuthController ligne 45 pour activer le cookie de session persistant via IntranetWeb.UserAuth.log_in_user/3 qui utilise le plug put_session avec une durée de 60 jours configurée dans user_auth.ex
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
- Menu de réservation de salles avec gestion des conflits
- Notifications email aux participants de réunions
- Masquage des titres de réunions pour non-participants

### Changed
- Amélioration du widget calendrier pour afficher réunions et réservations
- Simplification de la gestion des participants aux réservations

### Fixed
- Correction des accents dans messages de succès (réservations)
- Fix du rendu des noms et prénoms pour utilisateurs de test

## [1.5.0] - 2025-01-20

### Added
- Authentification Microsoft avec cookie persistant
- Client lourd avec retry automatique si serveur indisponible

### Fixed
- Gestion des erreurs de connexion dans client lourd

## [1.4.0] - 2025-01-10

...
```

## Intégration avec PRs

Le changelog peut être référencé dans le corps de la PR :

```markdown
## Résumé
Ajout du système de réservation de salles avec calendrier dynamique.

## Changements
Voir CHANGELOG.md section [Unreleased]

## Test plan
- [ ] Créer une réservation de salle
- [ ] Vérifier l'affichage dans le calendrier
- [ ] Tester les notifications email
```

## Notes

- Le changelog est un **document vivant**
- Il peut être remanié avant chaque release
- Il sert de base pour les notes de release
- Il aide à communiquer les changements aux utilisateurs
