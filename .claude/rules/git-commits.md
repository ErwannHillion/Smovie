# Git Commit Rules

## Nomenclature Obligatoire

**Format** : `SMOVIE-XXX type(scope): description`

### Exemples
- `SMOVIE-014 feat(notes): selecteur d etoiles par demi-crans`
- `SMOVIE-021 fix(reviews): corrige le compteur de likes apres un retrait`
- `SMOVIE-002 refacto(divers): supprime les live views de l ancienne version`

## Nomenclature des Branches

**La branche porte le nom du ticket.**

```bash
git switch -c SMOVIE-XXX-scope-description-du-ticket
```

### Nomenclature des tickets JIRA

**Format** : `[Scope] Description`

- `[Catalogue] Import a la demande depuis TMDB`
- `[Notes] Selecteur d etoiles et note Smovie bayesienne`
- `[Messagerie] Partage de films et de reviews`
- `[Secu] Durcissement des autorisations de conversation`
- `[Fix] ...`, `[Refacto] ...`, `[UX] ...`, `[Perf] ...`

**Pas de `feat(scope):` dans un titre de ticket** — ce format est réservé aux
messages de commit. Le script coupe tout ce qui précède un `:`, donc un titre
en `feat(analyse): ...` produit une branche sans verbe ni scope.

**Éviter accents et apostrophes dans les titres** : ils n'ont rien à faire dans un
nom de branche, et les retirer après coup donne des horreurs du genre
`secu-dition-des-packs-rserve-aux-rfrents`.

### Branches produites

| Ticket | Branche |
|---|---|
| `[Catalogue] Table works unifiee` | `SMOVIE-008-catalogue-table-works-unifiee` |
| `[Notes] Selecteur d etoiles et note bayesienne` | `SMOVIE-014-notes-selecteur-d-etoiles-et-note-bayesienne` |

## Types Autorisés

- `feat` - Nouvelle fonctionnalité
- `fix` - Correction de bug
- `refacto` - Refactoring sans changement de comportement
- `test` - Ajout ou modification de tests
- `docs` - Documentation
- `style` - Formatage, style (sans changement logique)
- `chore` - Tâches de maintenance
- `ops` - Configuration, déploiement

## Règles Strictes

❌ **INTERDIT** :
- Mentionner Claude, Claude Code, ou toute référence à l'IA
- Utiliser des emojis (sauf dans le corps si demandé)
- Omettre le préfixe SMOVIE-XXX

✅ **OBLIGATOIRE** :
- Préfixer avec SMOVIE-XXX (numéro de la branche)
- Message en français
- Description concise et claire
- Corps du commit pour détails supplémentaires

## Format du Corps

```
SMOVIE-XXX type(scope): titre court

Description détaillée si nécessaire.
Liste des changements :
- Changement 1
- Changement 2
```

## Avant Chaque Commit

1. Vérifier la branche courante avec `git branch --show-current`
2. Vérifier `git status`
3. Vérifier `git diff` pour comprendre les changements
4. **Vérifier si ajout/modification de config** :
   - Mettre à jour `.env.example` si nouvelle variable d'environnement
   - Mettre à jour `README.md` si variable obligatoire ou service externe
   - Vérifier que `System.get_env` est bien dans `config/runtime.exs` (pas dans le
     code), et que le code lit la configuration via `Smovie.Config`
5. S'assurer que les tests passent
6. Formater le code (`mix format`)
7. Vérifier la qualité avec `mix credo --strict`
8. **Vérifier les chaînes traduites** : toute chaîne visible passe par `gettext/1`,
   puis `mix gettext.extract --merge`
