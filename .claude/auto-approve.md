# Auto-Approvals - Actions Autorisées Sans Confirmation

Ce fichier définit les actions que l'assistant peut effectuer automatiquement sans demander de confirmation.

## Lecture de Fichiers

✅ **TOUJOURS autorisé** sans confirmation :
- Lire n'importe quel fichier du projet
- Lire les règles `.claude/rules/*`
- Lire les workflows `.claude/workflows/*`
- Lire les schémas Ecto
- Lire les contextes
- Lire les LiveViews/Controllers
- Lire les migrations
- Lire mix.exs, config/*, README.md, CHANGELOG.md

## Recherches et Analyses

✅ **TOUJOURS autorisé** sans confirmation :
- Glob pour trouver des fichiers
- Grep pour chercher du code
- Analyser la structure du projet
- Lire la documentation via MCP Tidewave (get_docs)
- Consulter les schémas via get_ecto_schemas
- Évaluer du code Elixir via project_eval (lecture seule)
- Exécuter des requêtes SQL en lecture seule via execute_sql_query

## Commandes Bash

✅ **TOUJOURS autorisé** sans confirmation :
- `git status`
- `git diff`
- `git log`
- `git branch --show-current`
- `git branch` (liste)
- `ls`, `cat`, `head`, `tail`
- `mix format --check-formatted`
- `mix compile` (sans modification)
- `mix test` (exécution)
- `mix credo --strict`

⚠️ **DEMANDER confirmation** :
- `git add`
- `git commit`
- `git push`
- `mix ecto.gen.migration`
- `mix ecto.migrate`
- `mix ecto.reset`
- Toute commande destructive

## Modifications de Fichiers

### ✅ Auto-approuvé

**Documentation** :
- Ajouter/modifier `@doc` et `@spec`
- Mettre à jour `CHANGELOG.md` section `[Unreleased]`
- Mettre à jour `.env.example` (ajout de variables)

**Formatage** :
- `mix format` sur fichiers modifiés
- Corrections de warnings de compilation
- Corrections de warnings Credo

**Tests** :
- Créer/modifier des fichiers de test `*_test.exs`
- Ajouter des fixtures de test

### ⚠️ Demander confirmation

**Code de production** :
- Créer/modifier des contextes
- Créer/modifier des LiveViews/Controllers
- Créer/modifier des schémas Ecto
- Créer/modifier des migrations
- Créer/modifier des seeds
- Créer/modifier du code JavaScript/CSS

**Configuration** :
- Modifier `config/*.exs`
- Modifier `mix.exs`
- Modifier `README.md` (sections principales)

**Base de données** :
- Exécuter des requêtes SQL d'écriture
- Modifier des données via execute_sql_query

## Agents et Workflows

✅ **TOUJOURS autorisé** sans confirmation :
- Lancer Agent Architecte (amont) pour proposer un plan
- Lancer Agent Code Review pour analyse
- Lancer Agent Performance pour détection
- Lancer Agent Database Safety pour validation
- Lancer Agent Functional Verification (lecture seule)

⚠️ **DEMANDER confirmation** avant :
- Lancer Agent Principal (écriture de code)
- Lancer Agent Test Writer (écriture de tests)
- Lancer le workflow complet `/feature`
- Créer un commit
- Créer une PR

## Git et Versioning

✅ **Auto-approuvé** :
- Vérifier la branche courante
- Afficher les changements (diff, status, log)
- Analyser l'historique

⚠️ **TOUJOURS demander** :
- Créer un commit
- Pousser vers remote
- Créer une PR
- Merger une branche
- Supprimer une branche

## Cas Particuliers

### Corrections Mineures Auto-approuvées
- Corriger une typo dans un commentaire
- Corriger un warning de compilation évident
- Ajouter un `@spec` manquant
- Formater du code non formaté

### Refactorings (DEMANDER)
- Renommer une fonction
- Déplacer du code entre modules
- Changer une signature de fonction
- Modifier une structure de données

## Exceptions

**Ne JAMAIS faire sans confirmation explicite** :
- Supprimer du code
- Modifier des migrations déjà mergées
- Modifier des données en production
- Changer des variables d'environnement critiques
- Désactiver des fonctionnalités existantes
- Modifier la logique métier sans validation

## Workflow Suggéré

Quand je propose une action, je peux :
1. ✅ **Faire directement** si dans la liste auto-approuvée
2. ⚠️ **Proposer et attendre** "oui" / "vas-y" / "ok" pour actions nécessitant confirmation
3. 🔴 **Toujours demander explicitement** pour actions critiques

## Comment Modifier Ces Règles

Pour ajouter/retirer des auto-approvals :
1. Modifier ce fichier `.claude/auto-approve.md`
2. Commit les changements
3. Les nouvelles règles s'appliquent immédiatement

## Notes

- Ces règles sont des **lignes directrices**, pas des contraintes techniques
- L'assistant peut toujours demander confirmation même pour des actions auto-approuvées si le contexte est ambigu
- L'utilisateur peut toujours interrompre une action en cours
