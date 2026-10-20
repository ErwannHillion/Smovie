# Git Commit Rules

## Nomenclature Obligatoire

**Format** : `REALTIX-XXX type(scope): description`

### Exemples
- `REALTIX-493 feat(auth): active remember_me automatiquement pour login Microsoft`
- `REALTIX-482 fix(calendar): correction affichage dates`
- `REALTIX-470 refacto(divers): nettoyage code`

## Nomenclature des Branches

**La branche porte le nom du ticket.** Elle se crée avec le script du repo, qui
dérive le nom du summary JIRA :

```bash
./scripts/jira-sync.sh create-branch REALTIX-XXX
```

### Nomenclature des tickets JIRA

**Format** : `[Scope] Description`

- `[Analyse] Provenance de chaque valeur du formulaire`
- `[Accounts] Pays utilisateur et modale de premiere connexion`
- `[Packs] Propagation des corrections de pack aux deals existants`
- `[Secu] Edition des packs reservee aux referents du pays`
- `[Fix] ...`, `[Refacto] ...`, `[UX] ...`, `[Perf] ...`

**Pas de `feat(scope):` dans un titre de ticket** — ce format est réservé aux
messages de commit. Le script coupe tout ce qui précède un `:`, donc un titre
en `feat(analyse): ...` produit une branche sans verbe ni scope.

**Éviter accents et apostrophes dans les titres** : le script les supprime, ce
qui donne `secu-dition-des-packs-rserve-aux-rfrents`.

### Branches produites

| Ticket | Branche |
|---|---|
| `[Analyse] Provenance de chaque valeur du formulaire` | `REALTIX-102-analyse-provenance-de-chaque-valeur-du-formulaire` |
| `[Pays] Analyse dependante du pays utilisateur` | `REALTIX-103-pays-analyse-dependante-du-pays-utilisateur` |

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
- Omettre le préfixe REALTIX-XXX

✅ **OBLIGATOIRE** :
- Préfixer avec REALTIX-XXX (numéro de la branche)
- Message en français
- Description concise et claire
- Corps du commit pour détails supplémentaires

## Format du Corps

```
REALTIX-XXX type(scope): titre court

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
   - Vérifier que `System.get_env` est bien dans `config/*.exs` (pas dans le code)
5. S'assurer que les tests passent
6. Formater le code (`mix format`)
7. Vérifier la qualité avec `mix credo --strict`
