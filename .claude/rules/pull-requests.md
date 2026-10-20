# Pull Request Guidelines

## Création de PR

### Workflow Standard

1. **Vérifier les changements**
   ```bash
   git status
   git diff
   ```

2. **Vérifier la documentation**
   - Mettre à jour `CHANGELOG.md` (section `[Unreleased]`)
   - Mettre à jour `.env.example` si nouvelle variable d'environnement
   - Mettre à jour `README.md` si variable obligatoire ou nouveau service externe
   - Suivre les règles de `changelog.md` et `configuration.md`

3. **Créer un commit propre**
   - Suivre les règles de `git-commits.md`
   - Message clair et descriptif
   - Inclure la mise à jour du CHANGELOG.md

4. **Push la branche**
   ```bash
   git push -u origin SMOVIE-XXX-description
   ```

5. **Créer la PR avec `gh`**
   ```bash
   gh pr create --title "SMOVIE-XXX type: description" --body "..."
   ```

## Structure de la PR

### Titre
Format : `SMOVIE-XXX type: description courte`

### Corps de la PR

```markdown
## Résumé
Description en 1-3 phrases du changement.

## Changements
- Changement 1
- Changement 2
- Changement 3

## Test plan
- [ ] Action de test 1
- [ ] Action de test 2
```

## Règles Strictes

❌ **INTERDIT** :
- Mentionner Claude, Claude Code, IA, "Generated with", "Co-Authored-By: Claude"

✅ **OBLIGATOIRE** :
- **TOUJOURS mettre à jour CHANGELOG.md** avant chaque PR
- **TOUJOURS mettre à jour .env.example** si nouvelle variable d'environnement
- **TOUJOURS mettre à jour README.md** si variable obligatoire ou nouveau service
- **TOUJOURS vérifier la branche courante** avec `git branch --show-current` avant commit/PR
- Utiliser le numéro SMOVIE-XXX de la branche courante (pas un ancien numéro !)
- Titre avec nomenclature SMOVIE-XXX
- Description du "pourquoi", pas juste du "quoi"
- Test plan clair
- Un seul sujet par PR (sauf refacto groupée)
