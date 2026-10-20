Lance le workflow complet de développement d'une fonctionnalité avec tous les agents (8 agents sur 5 phases).

Arguments : Description de la fonctionnalité à implémenter

Workflow :

**Phase 0 - Architecture (Amont)** :
- Lancer Agent Architecte pour :
  * Proposer le modèle de données (nomenclature FR/EN cohérente, Ecto.Enum, embedded schemas)
  * Identifier la réutilisation de l'existant (helpers, contextes, patterns)
  * Proposer architecture complexe si nécessaire (GenServer, LISTEN/NOTIFY, Broadway, Oban)
  * Définir le naming des fonctions (sémantiquement intelligent)
- Valider le plan avec l'utilisateur avant de continuer

**Phase 1 - Développement (Parallèle)** :
- Lancer Agent Principal pour implémenter la feature selon le plan de l'Architecte
- Lancer Agent Test Writer pour écrire les tests
- Lancer Agent Documentation pour mettre à jour la documentation

**Phase 2 - Validation (Parallèle)** :
- Lancer Agent Code Review pour valider le code (backend + frontend, DRY)
- Lancer Agent Performance pour détecter N+1, transactions manquantes, LiveView mount optimizations
- Lancer Agent Database Safety pour valider migrations (prefer change/0)

**Phase 3 - Vérification (Séquentiel)** :
- Lancer Agent Functional Verification pour test end-to-end

**Phase 4 - Validation Architecturale (Aval)** :
- Lancer Agent Architecte pour vérifier :
  * Cohérence du modèle de données implémenté
  * Naming des fonctions respecté
  * Terminologie FR/EN cohérente
  * Réemploi de l'existant effectif

**Phase 5 - Finalisation** :
Si tout est OK :
- Vérifier la branche courante avec `git branch --show-current`
- Compiler les résultats de tous les agents
- Proposer le commit avec nomenclature REALTIX-XXX
- CHANGELOG.md mis à jour

Présenter un résumé clair des actions de chaque agent et un rapport de validation.
