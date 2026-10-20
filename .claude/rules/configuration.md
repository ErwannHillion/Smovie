# Configuration Rules

## Variables d'Environnement

### Règle Absolue : System.get_env vs Application.get_env

**JAMAIS `System.get_env/1` dans le code applicatif.**
**TOUJOURS `Application.get_env/2` dans le code.**

```elixir
# ✅ Bon - Dans config/*.exs
config :intranet, :plane,
  api_url: System.get_env("PLANE_API_URL"),
  is_active: System.get_env("PLANE_IS_ACTIVE", "false") == "true"

# ✅ Bon - Dans le code applicatif
defmodule Intranet.ItSupport.PlaneClient do
  def get_api_url do
    Application.get_env(:intranet, :plane)[:api_url]
  end

  def active? do
    Application.get_env(:intranet, :plane)[:is_active]
  end
end

# ❌ Mauvais - System.get_env dans le code
defmodule Intranet.ItSupport.PlaneClient do
  def get_api_url do
    System.get_env("PLANE_API_URL")  # NON !
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
config :intranet, :features,
  show_orga_in_profile: false,
  show_bookings_in_home: false

# config/runtime.exs - Variables d'environnement (prod/preprod)
config :intranet, :plane,
  api_url: System.get_env("PLANE_API_URL"),
  is_active: System.get_env("PLANE_IS_ACTIVE", "false") == "true"

# config/dev.exs - Overrides pour développement
config :intranet, :features,
  show_orga_in_profile: true

# config/test.exs - Overrides pour tests
config :intranet, :plane,
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
  HTTPoison.post("https://api.plane.so/webhook", body)
end

# ✅ Bon - URL variabilisée
def send_webhook do
  url = Application.get_env(:intranet, :plane)[:webhook_url]
  HTTPoison.post(url, body)
end
```

### Exemples de Variabilisation

```elixir
# config/runtime.exs
config :intranet, :external_urls,
  webmail: System.get_env("URL_WEBMAIL_AQUARAY", "https://webmail.example.com"),
  lucca: System.get_env("URL_LUCCA", "https://lucca.example.com")
config :intranet, :emails,
  dpo: System.get_env("DPO_EMAIL", "dpo@inter-gestion.com"),
  support: System.get_env("SUPPORT_EMAIL", "support@inter-gestion.com")

config :intranet, :limits,
  max_file_size: String.to_integer(System.get_env("MAX_FILE_SIZE", "10485760")),
  pagination_default: String.to_integer(System.get_env("PAGINATION_DEFAULT", "50"))

# Dans le code
defmodule IntranetWeb.LayoutView do
  def webmail_url do
    Application.get_env(:intranet, :external_urls)[:webmail]
  end
end

defmodule Intranet.Support do
  def dpo_email do
    Application.get_env(:intranet, :emails)[:dpo]
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
PLANE_IS_ACTIVE=false
PLANE_API_URL=https://api.plane.so
PLANE_API_KEY=your-plane-api-key

# External URLs
URL_WEBMAIL_AQUARAY=https://webmail.example.com
URL_LUCCA=https://lucca.example.com

# Emails
DPO_EMAIL=dpo@inter-gestion.com
SUPPORT_EMAIL=support@inter-gestion.com

# Features (optional - defaults in config)
SHOW_ORGA_IN_PROFILE=false
SHOW_BOOKINGS_IN_HOME_CALENDAR=false

# Database (development only - production uses DATABASE_URL)
DB_USERNAME=postgres
DB_PASSWORD=postgres
DB_HOSTNAME=localhost
DB_NAME=intranet_dev
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
# Intranet

## Description
[Brève description du projet]

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
- `MICROSOFT_CLIENT_ID`, `MICROSOFT_CLIENT_SECRET`, `MICROSOFT_TENANT_ID`
- [Liste des vars obligatoires]

Variables optionnelles :
- `PLANE_IS_ACTIVE` (default: false)
- [Liste des vars optionnelles avec defaults]

### 3. Setup de la base de données
...

## Services Externes

### Microsoft OAuth
[Configuration OAuth]

### Plane.so (optionnel)
[Configuration Plane si activé]

## Fonctionnalités
- Authentification Microsoft
- Gestion des utilisateurs
- Réservations de salles
- [Autres features]

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

## Abstraction (Future)

**Note** : Pour l'instant, utiliser `Application.get_env/2` directement.

À terme, envisager une abstraction unifiée :

```elixir
# Future - Module de configuration centralisé
defmodule Intranet.Config do
  def plane_api_url, do: get(:plane, :api_url)
  def plane_active?, do: get(:plane, :is_active)
  def dpo_email, do: get(:emails, :dpo)

  defp get(key, subkey) do
    Application.get_env(:intranet, key)[subkey]
  end
end
```

Mais ne pas introduire avant d'avoir un plan de migration complet.
