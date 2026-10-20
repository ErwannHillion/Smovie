Affiche l'aide complète avec la liste des commandes disponibles et des agents.

## Commandes Disponibles

### Workflows et Agents
- `/workflow` ou `/workflow_help` - Affiche la documentation complète des agents
- `/feature <description>` - Lance le workflow complet de développement
- `/review` - Lance les agents de validation sur le code existant
- `/help` - Affiche cette aide

## Agents Spécialisés

Les agents travaillent en parallèle pour automatiser le développement.

### Phase 1 : Développement (Parallèle)
1. **Agent Principal** - Implémente la fonctionnalité
2. **Agent Test Writer** - Écrit les tests en parallèle
3. **Agent Documentation** - Met à jour @doc, CHANGELOG, .env.example, README

### Phase 2 : Validation (Parallèle)
4. **Agent Code Review** - Valide conventions, pattern matching, with vs case
5. **Agent Performance & Architecture** - Détecte N+1, transactions manquantes, optimisations LiveView
6. **Agent Database Safety** - Valide migrations, upserts, seeds

### Phase 3 : Vérification (Séquentiel)
7. **Agent Functional Verification** - Teste end-to-end la fonctionnalité

## Règles de Développement

Toutes les règles sont documentées dans `.claude/rules/` :
- `elixir-phoenix.md` - Conventions Elixir/Phoenix complètes
- `database.md` - Migrations, upserts, seeds
- `configuration.md` - Variables d'environnement, .env.example
- `git-commits.md` - Nomenclature SMOVIE-XXX, checklist
- `pull-requests.md` - Workflow PR, CHANGELOG
- `changelog.md` - Suivi des releases
- `project-specific.md` - Architecture Smovie

## Utilisation

**Lancer une feature complète** :
```
/feature Ajouter notifications email pour les réservations
```

**Valider du code existant** :
```
/review
```

**Voir la documentation complète** :
```
/workflow
```

Pour plus de détails sur les agents, utilise `/workflow`.
