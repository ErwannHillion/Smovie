# Configuration Rules

## Variables d'Environnement

### Règle Absolue : System.get_env vs Application.get_env

**JAMAIS `System.get_env/1` dans le code applicatif.**
**TOUJOURS `Application.get_env/2` dans le code.**

```elixir
# ✅ Bon - Dans config/*.exs
config :smovie, :tmdb,
  api_key: System.get_env("TMDB_API_KEY"),
  base_url: System.get_env("TMDB_BASE_URL", "https://api.themoviedb.org/3")

# ✅ Bon - Dans le code applicatif
defmodule Smovie.External.TMDB.Req do
  def get_api_url do
    Application.get_env(:smovie, :tmdb)[:api_url]
  end

  def active? do
    Application.get_env(:smovie, :tmdb)[:is_active]
  end
end

# ❌ Mauvais - System.get_env dans le code
defmodule Smovie.External.TMDB.Req do
  def get_api_url do
    System.get_env("TMDB_BASE_URL")  # NON !
  end
end
```

**Raison** :
- `System.get_env/1` lit l'environnement à chaque appel (runtime)
- `Application.get_env/2` utilise la config chargée au démarrage (compiletime/runtime selon config)
- Centralisation dans `config/*.exs` facilite la maintenance
- Testabilité : on peut override `Application` config, pas `System` env

### Emplacement des Configurations

**Fichiers de config** :
- `config/config.exs` - Configuration commune à tous les environnements
- `config/dev.exs` - Configuration développement
- `config/test.exs` - Configuration tests
- `config/prod.exs` - Configuration production
- `config/runtime.exs` - Configuration runtime (chargée au démarrage)

**Où mettre quoi** :

```elixir
# config/config.exs - Valeurs par défaut communes
config :smovie, :features,
  show_press_ratings: true,
  show_friends_block_on_home: true

# config/runtime.exs - Variables d'environnement (prod/preprod)
config :smovie, :tmdb,
  api_key: System.get_env("TMDB_API_KEY"),
  base_url: System.get_env("TMDB_BASE_URL", "https://api.themoviedb.org/3")

# config/dev.exs - Overrides pour développement
config :smovie, :features,
  show_press_ratings: false

# config/test.exs - Overrides pour tests
config :smovie, :tmdb,
  api_url: "http://localhost:4567",
  is_active: false
```

## Variabilisation

### JAMAIS de Valeurs en Dur

**TOUJOURS variabiliser** :
- URLs externes
- Clés API
- Emails de contact
- Timeouts
- Limites (pagination, taille fichiers, etc.)
- Chemins de fichiers
- Ports

```elixir
# ❌ Mauvais - URL en dur
def send_webhook do
  HTTPoison.post("https://api.themoviedb.org/3/webhook", body)
end

# ✅ Bon - URL variabilisée
def send_webhook do
  url = Application.get_env(:smovie, :tmdb)[:webhook_url]
  HTTPoison.post(url, body)
end
```

### Exemples de Variabilisation

```elixir
# config/runtime.exs
config :smovie, :tmdb,
  image_base_url: System.get_env("TMDB_IMAGE_BASE_URL", "https://image.tmdb.org/t/p"),
  language: System.get_env("TMDB_LANGUAGE", "fr-FR")
config :smovie, :emails,

config :smovie, :limits,
  max_file_size: String.to_integer(System.get_env("MAX_FILE_SIZE", "10485760")),
  pagination_default: String.to_integer(System.get_env("PAGINATION_DEFAULT", "50"))

# Dans le code
defmodule SmovieWeb.WorkComponents do
  def image_base_url do
    Application.get_env(:smovie, :tmdb)[:image_base_url]
  end
end

defmodule Smovie.Trending do
  def window_days do
    Application.get_env(:smovie, :trending)[:window_days]
  end
end
```

## .env.example

### Mise à Jour Obligatoire

**TOUJOURS mettre à jour `.env.example`** quand vous ajoutez une variable d'environnement.

**Workflow** :
1. Ajout d'une variable dans `config/*.exs` via `System.get_env("NEW_VAR")`
2. Immédiatement ajouter `NEW_VAR=valeur_exemple` dans `.env.example`
3. Commit les deux fichiers ensemble

### Format .env.example

```bash
# Authentication
MICROSOFT_CLIENT_ID=your-client-id
MICROSOFT_CLIENT_SECRET=your-client-secret
MICROSOFT_TENANT_ID=your-tenant-id

# External Services
OMDB_IS_ACTIVE=false
TMDB_BASE_URL=https://api.themoviedb.org/3
TMDB_API_KEY=your-plane-api-key

# External URLs
TMDB_IMAGE_BASE_URL=https://image.tmdb.org/t/p
TMDB_LANGUAGE=fr-FR

# Emails

# Features (optional - defaults in config)
SHOW_ORGA_IN_PROFILE=false
SHOW_BOOKINGS_IN_HOME_CALENDAR=false

# Database (development only - production uses DATABASE_URL)
DB_USERNAME=postgres
DB_PASSWORD=postgres
DB_HOSTNAME=localhost
DB_NAME=smovie_dev
```

**Règles** :
- Grouper par catégorie avec commentaires
- Valeurs d'exemple réalistes mais non sensibles
- Indiquer si optionnel et valeur par défaut
- Expliquer brièvement les variables peu évidentes

## README.md

### Mise à Jour Obligatoire

**TOUJOURS mettre à jour `README.md`** dans ces cas :

1. **Nouvelle variable d'environnement obligatoire**
   - Ajouter dans la section "Configuration"
   - Expliquer son rôle

2. **Nouvelle dépendance système**
   - Ajouter dans la section "Prérequis"
   - Expliquer comment l'installer

3. **Nouveau service externe**
   - Ajouter dans la section "Services externes"
   - Lien vers documentation

4. **Changement de workflow de développement**
   - Mettre à jour les instructions de setup
   - Documenter les nouveaux scripts/commandes

5. **Nouvelle fonctionnalité majeure**
   - Ajouter dans la section "Fonctionnalités"
   - Brève description

### Sections Obligatoires du README

```markdown
# Smovie

## Description
Letterboxd francophone : films et series, notation jusqu a l episode, social et messagerie.

## Prérequis
- Elixir 1.18+
- PostgreSQL 14+
- Node.js 18+ (pour assets)
- [Autres dépendances système]

## Installation

### 1. Cloner le projet
...

### 2. Variables d'environnement
Copier `.env.example` vers `.env` et remplir les valeurs :
```bash
cp .env.example .env
```

Variables obligatoires :
- `DATABASE_URL` (production)
- `TMDB_API_KEY`
- `SECRET_KEY_BASE` (production)

Variables optionnelles :
- `OMDB_IS_ACTIVE` (default: false)
- `TMDB_LANGUAGE` (default: fr-FR)

### 3. Setup de la base de données
...

## Services Externes

### TMDB
[Clé API, langue, région]

### OMDb (optionnel)
[Configuration OMDb si activé — notes presse]

## Fonctionnalités
- Catalogue films et séries importé de TMDB
- Notation en demi-étoiles, jusqu'à l'épisode
- Reviews, abonnements, watchlist
- Messagerie privée et de groupe

## Développement
[Instructions pour développer]
```

## Checklist Avant PR

Quand vous ajoutez/modifiez une configuration :

- [ ] Variable ajoutée dans `config/*.exs` avec `System.get_env`
- [ ] Code utilise `Application.get_env` (pas `System.get_env`)
- [ ] `.env.example` mis à jour avec exemple
- [ ] `README.md` mis à jour si variable obligatoire ou service externe
- [ ] `CHANGELOG.md` mis à jour si changement impacte les utilisateurs
- [ ] Documentation de la variable (commentaire dans config)

## Le module Smovie.Config

**Non négociable** : le code applicatif lit la configuration via `Smovie.Config`,
jamais `Application.get_env/2` en direct (check `.credo/no_direct_application_get_env.ex`).

```elixir
# Future - Module de configuration centralisé
defmodule Smovie.Config do
  def plane_api_url, do: get(:tmdb, :api_url)
  def plane_active?, do: get(:tmdb, :is_active)
  def omdb_enabled?, do: get(:omdb, :enabled)

  defp get(key, subkey) do
    Application.get_env(:smovie, key)[subkey]
  end
end
```

`Smovie.Config` est le **seul** module autorisé à appeler `Application.get_env/2`.
