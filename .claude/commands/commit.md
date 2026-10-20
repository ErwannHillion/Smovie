Créer un commit selon les règles du projet.

Arguments : Aucun (analyse automatique des changements)

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

5. **Valider avec l'utilisateur** avant de commiter

6. **Créer le commit** avec `git add` + `git commit -m` (utiliser HEREDOC pour le message)

7. **Vérifier le succès** avec `git status`

## Exemple de message

```
REALTIX-514 fix(commands): ajout Agent Architecte dans /feature

Correction de l'incohérence entre /feature et /workflow :
- Ajout Phase 0 : Agent Architecte (amont)
- Ajout Phase 4 : Agent Architecte (aval)
- Passage de 7 à 8 agents, de 4 à 5 phases
```
