# Agents Spécialisés - Documentation

## Vue d'ensemble

Les agents sont des instances spécialisées qui travaillent en parallèle pour automatiser différentes parties du workflow de développement.

## Liste des Agents

### 0. Agent Architecte (Amont & Aval)
**Rôle** : Chef d'orchestre de la conception et validation architecturale

**Responsabilités Amont** (avant développement) :
- **Proposition du modèle de données** :
  * Nomenclature réfléchie et cohérente (choisir entre termes français/anglais pour un contexte)
  * Lecture de l'existant (schémas, contextes, fonctions)
  * Ajout ou non aux contextes existants
  * Proposition d'embedded schemas quand pertinent
  * Contraintes d'unicité réfléchies (pas systématiques)
  * `Ecto.Enum` quand valeurs restreintes
  * Minimiser traductions intermédiaires pour utiliser `Ecto.Enum.values/1`
- **Réutilisation de l'existant** :
  * Fonctions Helper existantes
  * Modules de contexte existants
  * Patterns déjà implémentés
- **Propositions architecture complexe** (quand pertinent) :
  * GenServers
  * LISTEN/NOTIFY PostgreSQL
  * Broadway pour data pipelines
  * Oban pour jobs en arrière-plan
- **Naming des fonctions** :
  * Sémantiquement intelligentes
  * Porteuses de sens métier
  * Cohérentes avec l'existant

**Responsabilités Aval** (après chaque commit) :
- Vérifier qu'on est "on track" sur le modèle de données
- Valider le naming des fonctions
- Confirmer la cohérence terminologique (FR/EN)
- S'assurer du réemploi de l'existant

**Sortie** :
- Plan architectural détaillé
- Modèle de données proposé
- Nomenclature à suivre
- Validation post-commit

**Exécution** :
- **Début** : Avant Agent Principal
- **Fin** : Après tous les commits

---

### 1. Agent Principal (Développement)
**Rôle** : Implémentation de la fonctionnalité demandée selon le plan de l'Architecte

**Responsabilités** :
- Suivre le plan architectural proposé
- Écrire le code de la feature
- Suivre les règles `.claude/rules/`
- Créer les migrations via `mix ecto.gen.migration`
- Utiliser les contextes appropriés
- Pattern matching, `with` vs `case`
- Configuration via `Application.get_env`
- Respecter la nomenclature proposée par l'Architecte

**Sortie** : Code fonctionnel prêt à tester

**Exécution** : Après Agent Architecte (amont)

---

### 2. Agent Test Writer
**Rôle** : Écriture des tests en parallèle du développement

**Responsabilités** :
- Tests unitaires pour contextes
- Tests d'intégration pour LiveViews
- Tests des migrations
- Utiliser les fixtures appropriées
- Suivre la règle "tests au fur et à mesure"

**Sortie** : Fichiers de tests complets

**Exécution** : En parallèle avec Agent Principal

---

### 3. Agent Documentation
**Rôle** : Mise à jour de la documentation en parallèle

**Responsabilités** :
- Ajouter `@doc` et `@spec` pour nouvelles fonctions
- Format avec typespec, contexte, exemples
- Mettre à jour `.env.example` si nouvelle variable d'environnement
- Mettre à jour `README.md` si variable obligatoire ou service externe
- Mettre à jour `CHANGELOG.md` section `[Unreleased]`

**Sortie** : Documentation complète et à jour

**Exécution** : En parallèle avec Agent Principal

---

### 4. Agent Code Review
**Rôle** : Validation du code après développement

**Responsabilités Backend** :
- Conformité aux règles `.claude/rules/`
- Pattern matching correctement utilisé
- Déstructuration dans signatures
- Variables booléennes (`is_*`, fonctions `?`)
- Fonctions avec `!` cohérentes
- Séquençage `case` vs `with` (règles 1/2/3)
- Try/rescue inapproprié
- **CHASSE au `length/1`** pour vérifier listes vides (utiliser `Enum.empty?` ou `!= []`)
- Helpers réutilisés vs code dupliqué
- PubSub hors transactions
- **DRY** :
  * Dans le commit
  * Dans la PR
  * Dans tout le code
  * Réutilisation de l'existant

**Responsabilités Frontend** :
- **Aucun code Ecto dans LiveViews/Controllers**
- **Bannir `<form>`, TOUJOURS `<.form>`** avec changesets Phoenix
- **DaisyUI + Tailwind obligatoires** :
  * Nettoyage du CSS custom (ex: `calendar.css`)
  * Aucune optimisation Tailwind = pollution
  * Pas de CSS vanilla dans fichiers `.css`
- **Regroupement des fonctions** entre elles (privées ensemble, publiques ensemble)
- **Usage correct de `handle_params`** (routing, state from URL)
- **Appels bloquants vs async** : favoriser `assign_async`, `start_async`

**Sortie** : Liste de suggestions d'amélioration

**Exécution** : Après Agent Principal (séquentiel)

---

### 5. Agent Performance & Architecture
**Rôle** : Détection des problèmes de performance et d'architecture

**Responsabilités** :
- **N+1 queries** : Détecter appels de fonctions dans boucles
- **Refactorings suggérés** : Joins utiles, préchargements optimaux
- **Transactions manquantes** : Opérations multiples qui devraient être atomiques
- **LiveView mount optimizations** :
  * Appels inutiles avant `connected?(socket)`
  * Appels en double (Macro.Notification vs on_mount hook)
  * Données chargées mais non utilisées
- **Requêtes Ecto** :
  * Manque de `preload`
  * `select` inutilement large
  * Joins possibles non utilisés
- **Configuration** : `System.get_env` dans le code au lieu de `Application.get_env`

**Sortie** : Rapport de performance avec suggestions de refactoring

**Exécution** : En parallèle avec Agent Code Review

**Complexité** :
- ⚠️ N+1 queries : Détection possible (chercher appels de fonctions contexte dans `Enum.map`)
- ⚠️ Transactions : Heuristique (multiples `Repo.insert/update/delete` séquentiels)
- ⚠️ LiveView mount : Complexe (nécessite analyse du flow complet)

---

### 6. Agent Database Safety
**Rôle** : Validation des opérations de base de données

**Responsabilités** :
- Migrations créées via `mix ecto.gen.migration`
- **Préférer `change/0` plutôt que `up/down`** (sauf cas complexes nécessitant rollback custom)
- Upserts utilisés (`on_conflict`) vs retrieve-then-insert
- Seeds idempotents avec upserts
- Demander confirmation pour modifications de données existantes
- Vérifier indexation des colonnes recherchées

**Sortie** : Validation des migrations et opérations DB

**Exécution** : En parallèle avec Agent Code Review

---

### 7. Agent Functional Verification
**Rôle** : Test end-to-end de la fonctionnalité

**Responsabilités Backend** :
- Lancer `mix phx.server` et vérifier aucun warning/erreur
- Tester via `mix run -e "..."` ou IEx
- Vérifier l'effet de bord attendu (ex: données en base)

**Responsabilités Frontend** :
- Avec MCP Chrome (à venir) : Vérifier rendu visuel
- En attendant : Instructions pour test manuel

**Sortie** : Confirmation que la feature fonctionne réellement

**Exécution** : Après tous les agents de validation (séquentiel)

---

## Workflow Complet

### Déclenchement
```
User: "/feature <description>"
ou
User: "Implémente <feature>, lance les agents en parallèle"
```

### Phases

#### Phase 0 : Architecture (Amont)
```
┌─────────────────────┐
│  Agent Architecte   │  Propose modèle de données, nomenclature, réutilisation
└─────────────────────┘
         │
         ▼
    Plan validé par user
```

#### Phase 1 : Développement (Parallèle)
```
┌─────────────────────┐
│  Agent Principal    │  Écrit le code selon plan Architecte
├─────────────────────┤
│  Agent Test Writer  │  Écrit les tests
├─────────────────────┤
│  Agent Documentation│  Met à jour docs
└─────────────────────┘
```

#### Phase 2 : Validation (Parallèle)
```
┌──────────────────────────┐
│  Agent Code Review       │  Valide code backend + frontend, DRY
├──────────────────────────┤
│  Agent Performance       │  Détecte N+1, transactions, refactorings
├──────────────────────────┤
│  Agent Database Safety   │  Valide migrations (prefer change)
└──────────────────────────┘
```

#### Phase 3 : Vérification (Séquentiel)
```
┌───────────────────────────────┐
│  Agent Functional Verification│  Teste end-to-end
└───────────────────────────────┘
```

#### Phase 4 : Validation Architecturale (Aval)
```
┌─────────────────────┐
│  Agent Architecte   │  Vérifie cohérence modèle, naming, réemploi
└─────────────────────┘
```

#### Phase 5 : Finalisation
```
Si tout OK :
  - Commit avec nomenclature SMOVIE-XXX
  - CHANGELOG.md mis à jour
  - Prêt pour PR
```

## Détection des Problèmes Complexes

### N+1 Queries

**Pattern à détecter** :
```elixir
# ❌ Problème
users = Repo.all(User)
Enum.map(users, fn user ->
  Posts.list_posts_for_user(user.id)  # Appel de fonction contexte dans boucle
end)

# ❌ Problème subtil
users = Repo.all(User)
Enum.map(users, fn user ->
  user.organization.name  # Association non préchargée
end)
```

**Heuristique de détection** :
1. Chercher `Enum.map`, `Enum.each`, `for` avec liste issue de `Repo`
2. Dans le corps, chercher :
   - Appels à fonctions de contexte (pattern `Module.function(item.id)`)
   - Accès à associations (`item.association.field`)
3. Vérifier si `preload` est absent dans la query initiale

**Faux positifs possibles** : Transformations simples sans query

---

### Transactions Manquantes

**Pattern à détecter** :
```elixir
# ❌ Devrait être une transaction
def register_user_to_training(user_id, training_id) do
  {:ok, registration} = Repo.insert(registration)
  {:ok, _} = Repo.update(training_changeset)
  {:ok, _} = Repo.insert(notification)
  {:ok, registration}
end
```

**Heuristique de détection** :
1. Fonction avec 2+ appels `Repo.insert/update/delete` séquentiels
2. Sans `Repo.transaction` englobant
3. Surtout si les opérations sont liées (même domaine métier)

**Faux positifs possibles** : Opérations indépendantes qui peuvent échouer séparément

---

### Cohérence Terminologique FR/EN

**Problème** : Mélange français/anglais dans un même contexte

```elixir
# ❌ Incohérent
schema "trainings" do
  field :nom, :string          # FR
  field :description, :string  # FR/EN ambigu
  field :status, Ecto.Enum, values: [:actif, :pending, :cancelled]  # Mélange !
end

# ✅ Cohérent - Tout EN
schema "trainings" do
  field :name, :string
  field :description, :string
  field :status, Ecto.Enum, values: [:active, :pending, :cancelled]
end

# ✅ Cohérent - Tout FR (si contexte métier français)
schema "formations" do
  field :nom, :string
  field :description, :string
  field :statut, Ecto.Enum, values: [:actif, :en_attente, :annule]
end
```

**Heuristique de détection** :
1. Analyser les champs d'un schema
2. Analyser les valeurs d'un `Ecto.Enum`
3. Détecter mélange FR/EN
4. Proposer standardisation

**Responsable** : Agent Architecte (amont) + Agent Code Review (validation)

---

### LiveView Mount Optimizations

**Problème 1 : Appels avant `connected?`**
```elixir
# ❌ Charge des données lourdes avant connexion
def mount(_params, _session, socket) do
  users = Accounts.list_all_users_with_posts()  # N+1 potentiel + inutile si non connecté
  {:ok, assign(socket, :users, users)}
end

# ✅ Bon
def mount(_params, _session, socket) do
  socket = assign(socket, :users, [])

  if connected?(socket) do
    {:ok, assign(socket, :users, Accounts.list_all_users_with_posts())}
  else
    {:ok, socket}
  end
end
```

**Problème 2 : Appels en double (on_mount vs mount)**
```elixir
# Dans router.ex
live_session :default, on_mount: SmovieWeb.UserLiveAuth do
  # UserLiveAuth charge current_user
end

# ❌ Recharge le user dans mount
def mount(_params, _session, socket) do
  user = Accounts.get_user!(socket.assigns.current_user.id)  # Déjà chargé !
  {:ok, assign(socket, :user, user)}
end
```

**Problème 3 : Appels bloquants vs async**
```elixir
# ❌ Bloquant
def mount(_params, _session, socket) do
  users = Accounts.list_users()  # Bloque le rendu
  posts = Posts.list_posts()     # Bloque le rendu
  {:ok, assign(socket, users: users, posts: posts)}
end

# ✅ Async
def mount(_params, _session, socket) do
  socket =
    socket
    |> assign_async(:users, fn -> {:ok, %{users: Accounts.list_users()}} end)
    |> assign_async(:posts, fn -> {:ok, %{posts: Posts.list_posts()}} end)

  {:ok, socket}
end
```

**Heuristique de détection** :
1. Chercher appels de fonctions contexte dans `mount/3`
2. Vérifier si non conditionné par `connected?(socket)`
3. Vérifier si données déjà dans `socket.assigns` via `on_mount`
4. Vérifier usage de `assign_async` pour appels lourds

**Complexité** : ⚠️ Nécessite analyse du flow complet (router → on_mount → mount)

**Responsables** : Agent Performance (détection) + Agent Code Review (validation)

---

### CSS Custom vs Tailwind/DaisyUI

**Problème** : Pollution de fichiers CSS custom au lieu d'utiliser Tailwind

```css
/* ❌ Dans assets/css/calendar.css - Pollution */
.calendar-event {
  background-color: #3b82f6;
  padding: 8px;
  border-radius: 4px;
  margin-bottom: 4px;
}

.calendar-title {
  font-weight: bold;
  font-size: 14px;
}
```

```elixir
<!-- ✅ Tailwind + DaisyUI -->
<div class="bg-primary p-2 rounded mb-1">
  <h3 class="font-bold text-sm"><%= event.title %></h3>
</div>
```

**Heuristique de détection** :
1. Chercher nouveaux fichiers `.css` créés
2. Chercher ajouts dans fichiers CSS existants
3. Proposer équivalents Tailwind/DaisyUI

**Responsable** : Agent Code Review

---

## Limitations Actuelles

**Ce qui fonctionne** :
- Lancement d'agents en parallèle via outil `Task`
- Agents retournent résultats indépendamment
- Compilation des résultats

**Ce qui ne fonctionne PAS** :
- Communication inter-agents
- Validation croisée automatique
- Hooks automatiques (nécessite déclenchement manuel)
- Persistance entre sessions

## Commandes Disponibles

### `/workflow` ou `/workflow_help`
Affiche cette documentation et la liste des agents.

### `/feature <description>`
Lance le workflow complet avec tous les agents (Phase 0 à 5).

### `/review`
Lance uniquement les agents de validation (Code Review, Performance, Database Safety).

### `/test <module>`
Lance uniquement l'Agent Test Writer pour un module spécifique.

## Améliorations Futures

- [ ] MCP Chrome pour vérification visuelle frontend
- [ ] Communication inter-agents pour validation croisée
- [ ] Hooks Git pré-configurés pour agents de validation
- [ ] Agents persistants entre sessions
- [ ] Détection automatique du besoin de transactions
- [ ] Analyse complète du flow LiveView (router → on_mount → mount)
- [ ] Détection automatique mélange FR/EN
- [ ] Suggestions de refactoring automatiques (joins, préchargements)
