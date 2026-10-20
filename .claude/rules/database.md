# Database Rules

## Migrations

### Création de Migrations

**TOUJOURS utiliser `mix ecto.gen.migration`** pour créer les migrations.

```bash
# ✅ Bon
mix ecto.gen.migration add_status_to_users

# ❌ Mauvais - Créer le fichier manuellement
touch priv/repo/migrations/20250121_add_status.exs
```

**Raison** : `mix ecto.gen.migration` génère le timestamp correct et la structure de base.

### Environnement de Développement

✅ **Autorisé en DEV** :
- Créer des migrations via `mix ecto.gen.migration`
- Modifier des migrations non encore mergées
- `mix ecto.reset` si nécessaire
- Expérimenter avec la structure

### Bonnes Pratiques

✅ **Toujours** :
- Utiliser `mix ecto.gen.migration` pour créer
- Nommer les migrations de manière descriptive
- Tester les migrations localement avant commit
- Prévoir un rollback (`down` function)
- Utiliser des transactions pour les migrations complexes

❌ **Éviter** :
- Modifier une migration déjà mergée en production
- Supprimer des colonnes sans plan de migration
- Changer le type d'une colonne peuplée sans gestion des données existantes

### Modifier des Données Existantes

⚠️ **TOUJOURS demander** avant de créer une migration :
- "Veux-tu que je modifie aussi les données existantes ?"
- "Ou juste le schema ?"

Ne JAMAIS supposer. Toujours clarifier.

### Exemples

```elixir
# ✅ Migration sûre
def change do
  alter table(:users) do
    add :phone, :string
    add :verified, :boolean, default: false
  end
end

# ⚠️ Migration qui modifie des données - DEMANDER CONFIRMATION
def up do
  alter table(:users) do
    add :status, :string, default: "active"
  end

  # Mise à jour des données existantes
  execute "UPDATE users SET status = 'active' WHERE status IS NULL"
end

def down do
  alter table(:users) do
    remove :status
  end
end
```

## Requêtes Ecto

### Upserts (Insert or Update)

**TOUJOURS préférer** les upserts avec `on_conflict` plutôt que retrieve-then-insert.

```elixir
# ✅ Bon - Upsert idempotent
def upsert_user(email, attrs) do
  %User{email: email}
  |> User.changeset(attrs)
  |> Repo.insert(
    on_conflict: {:replace_all_except, [:id, :inserted_at]},
    conflict_target: :email
  )
end

# ❌ Éviter - Retrieve puis insert
def upsert_user(email, attrs) do
  case Repo.get_by(User, email: email) do
    nil -> Repo.insert(%User{email: email} |> User.changeset(attrs))
    user -> Repo.update(User.changeset(user, attrs))
  end
end
```

**Raison** : Upserts sont atomiques, évitent les race conditions, et plus performants.

### Performance

- Toujours précharger les associations nécessaires
- Utiliser `select` pour limiter les colonnes
- Paginer les listes avec Flop
- Indexer les colonnes fréquemment recherchées

### Exemple

```elixir
# ✅ Bon - Précharge les associations
Repo.all(
  from u in User,
  where: u.active == true,
  preload: [:profile, :organization]
)

# ❌ Éviter - N+1 queries
users = Repo.all(User)
Enum.map(users, fn u -> u.profile end)
```

## Seeds

- Idempotent : peut être exécuté plusieurs fois
- Ne jamais supprimer de données existantes
- **Préférer upserts** avec `on_conflict`

```elixir
# ✅ Idempotent avec upsert
%User{email: "admin@example.com"}
|> User.changeset(%{name: "Admin", role: :admin})
|> Repo.insert(
  on_conflict: :nothing,
  conflict_target: :email
)

# ❌ Éviter - Non idempotent
Repo.insert!(%User{email: "admin@example.com", name: "Admin"})
```

## Outils MCP Tidewave

Utiliser `execute_sql_query` pour :
- Inspecter la base de données
- Vérifier l'état des données
- **JAMAIS pour modifier des données** (sauf demande explicite)

Limiter à 50 lignes par requête par défaut.

### Préférer IEx

Pour des opérations complexes, préférer IEx et le code Elixir :

```elixir
# ✅ Bon - Dans IEx
iex> Smovie.Repo.all(Smovie.Accounts.User) |> Enum.count()

# ❌ Éviter - SQL brut
$ psql -d smovie_dev -c "SELECT COUNT(*) FROM users;"
```
