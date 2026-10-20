Créer un commit selon les règles du projet, pusher sur le remote, et créer une Pull Request.

Arguments :
- `assignee` (optionnel) : Nom d'utilisateur GitHub à qui assigner la PR (ex: `Tristan-flores`)
- Si non fourni, la PR sera créée sans assignation

## Workflow

1. **Vérifier la branche courante** avec `git branch --show-current` pour extraire REALTIX-XXX
2. **Analyser les changements** :
   - `git status` pour voir les fichiers modifiés
   - `git diff` pour comprendre les changements
   - `git log -5 --oneline` pour suivre le style des commits récents

3. **Vérifier si ajout/modification de config** :
   - Mettre à jour `.env.example` si nouvelle variable d'environnement
   - Mettre à jour `README.md` si variable obligatoire ou service externe
   - Vérifier que `System.get_env` est bien dans `config/*.exs` (pas dans le code)

4. **Proposer un message de commit** respectant les règles `.claude/rules/git-commits.md` :
   - Format : `REALTIX-XXX type(scope): description`
   - Types : `feat`, `fix`, `refacto`, `test`, `docs`, `style`, `chore`, `ops`
   - **INTERDIT** : Mentionner Claude, Claude Code, ou toute référence à l'IA
   - **INTERDIT** : Utiliser des emojis (sauf dans le corps si demandé)
   - **OBLIGATOIRE** : Préfixe REALTIX-XXX, message en français
   - Corps du commit avec détails si nécessaire

5. **Valider avec l'utilisateur** avant de commiter, pusher et créer la PR

6. **Créer le commit** avec `git add` + `git commit -m` (utiliser HEREDOC pour le message)

7. **Pusher sur le remote** :
   - Vérifier si la branche existe sur le remote avec `git branch -r | grep nom-branche`
   - Si première fois : `git push -u origin nom-branche`
   - Sinon : `git push`

8. **Analyser tous les commits de la branche** :
   - Utiliser `git log main..HEAD` pour voir TOUS les commits depuis le divergence de main
   - Analyser `git diff main...HEAD` pour comprendre l'ensemble des changements
   - **IMPORTANT** : Identifier les commits créés sur cette branche vs ceux hérités d'une branche parente
     - Les commits hérités d'une branche parente seront probablement écrasés lors du rebase
     - Ne pas les décrire en détail dans la PR
     - Se concentrer uniquement sur les commits nouveaux de la branche courante

9. **Créer la Pull Request** avec `gh pr create` selon les règles `.claude/rules/pull-requests.md` :
   - Titre : `REALTIX-XXX: Description concise`
   - Corps avec sections :
     - **Contexte** : Pourquoi ce changement
     - **Modifications** : Liste détaillée des changements
     - **Tests** : Comment tester
     - **Screenshots** : Si changements visuels
   - **INTERDIT** : Mentionner Claude, Claude Code, ou toute référence à l'IA
   - Utiliser HEREDOC pour le body de la PR
   - Si un `assignee` est fourni, ajouter `--assignee <username>` à la commande `gh pr create`

10. **Retourner l'URL de la PR** pour que l'utilisateur puisse la consulter

## Exemples d'utilisation

```bash
# PR sans assignation
/commit_push_and_pr

# PR assignée à Tristan-flores
/commit_push_and_pr Tristan-flores
```

## Format du corps de PR

**Note importante** : La PR doit décrire uniquement les commits **nouveaux** créés sur cette branche, pas ceux hérités d'une branche parente qui seront écrasés lors du rebase.

```
## Contexte
[Explication du problème ou besoin]

## Modifications
[Décrire UNIQUEMENT les commits nouveaux de cette branche]
- Modification 1
- Modification 2
- Modification 3

## Tests
- [ ] Tests unitaires passent
- [ ] Tests d'intégration passent
- [ ] Testé manuellement sur [environnement]

## Screenshots
[Si applicable]

## Checklist
- [ ] Code formaté (`mix format`)
- [ ] Qualité vérifiée (`mix credo --strict`)
- [ ] Documentation à jour
- [ ] CHANGELOG.md mis à jour
```
