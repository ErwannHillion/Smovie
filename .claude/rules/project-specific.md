# Intranet - Règles Spécifiques au Projet

## Architecture

### Contextes Principaux

- **Accounts** - Gestion des utilisateurs
- **Authorization** - Système de permissions par domaine
- **Analytics** - Tracking des erreurs et événements
- **Communication** - Posts, événements, onboarding
- **Training** - Formations et inscriptions
- **ItSupport** - Tickets, inventaire IT
- **Resources** - Réservations de salles
- **Organization** - Organigramme, services

### Espaces Web

- **UserSpace** - Interface utilisateur standard
- **AdminSpace** - Interface d'administration
- **RhSpace** - Espace RH
- **CommunicationSpace** - Espace communication
- **TrainingSpace** - Espace formation
- **ItSupportSpace** - Espace IT

## Authentification

### OAuth Microsoft

Le projet utilise OAuth Microsoft pour l'authentification principale.

**Cookie persistant** : Toujours activer `remember_me=true` pour :
- Login Microsoft (`auth_controller.ex`)
- Client lourd Tauri (conserve session 60 jours)

### Scopes

Le système utilise des "scopes" pour gérer les sessions :
- `current_scope` - Session utilisateur courante
- Contient `user` et informations de session
- Géré par `IntranetWeb.UserAuth`

## Features Spécifiques

### Plane Integration

- Système de tickets IT intégré avec Plane.so
- Webhooks pour synchronisation bidirectionnelle
- Configuration par environnement (dev/preprod/prod)
- **IMPORTANT** : Peut être désactivé via `PLANE_IS_ACTIVE=false`

### Client Lourd Rust/Tauri

Projet séparé : `/Users/olivierdeprez/sources/client-lourd-rust`

**Routes dédiées** :
- `/client-lourd/home` - Point d'entrée
- Pipeline `:client_lourd` avec `UserSocketAuth`
- Cookie remember_me automatique

**Gestion de connexion** :
- Page de chargement avec retry automatique
- Message d'erreur user-friendly
- Bouton "Réessayer" si serveur down

### Réservations de Salles

- Calendrier avec événements et réservations
- Notifications par email aux participants
- Gestion des conflits de réservation
- Widget calendrier dynamique sur page d'accueil

### Système de Notifications

- Badges de notifications en temps réel
- Notifications email via Swoosh
- Local adapter en dev, SMTP en prod

## Variables d'Environnement

### Critiques (TOUJOURS requises)

- `DATABASE_URL` (prod)
- `SECRET_KEY_BASE` (prod)
- `MICROSOFT_CLIENT_ID`, `MICROSOFT_CLIENT_SECRET`, `MICROSOFT_TENANT_ID`
- URLs externes : `URL_WEBMAIL_AQUARAY`, `URL_LUCCA`, `URL_EDOC`, `URL_PASSBOLT`
- Azure : `AZURE_BASE_URL`, `AZURE_API_SECRET`

### Optionnelles

- `PLANE_IS_ACTIVE` (default: false)
- `PLANE_API_URL_*` (seulement si Plane activé)
- `TELEMETRY_UP` (default: false)
- `SHOW_ORGA_IN_PROFILE` (default: false)
- `SHOW_BOOKINGS_IN_HOME_CALENDAR` (default: false)
- `DPO_EMAIL` (default: dpo@inter-gestion.com)

## CI/CD

### GitHub Actions

Workflow : `.github/workflows/elixir.yml`

**Vérifie** :
- Nomenclature commits (REALTIX-XXX)
- Absence de références Claude
- Tests
- Formatage (`mix format --check-formatted`)
- Credo

**Important** : Ne tourne pas en environnement `test` pour toutes les commandes.

## Bonnes Pratiques Spécifiques

### Internationalisation

- Français par défaut
- Anglais disponible via Gettext
- Locale stockée dans session utilisateur

### Mode Sombre

- Géré par plug `IntranetWeb.Plugs.Locale`
- Persiste dans cookies utilisateur

### Analytics

- Tracking des erreurs 4xx/5xx
- Tracking des clics sur liens externes
- Module `Intranet.Analytics`

### MCP Tidewave

**Repos disponibles** :
- `Intranet.Repo` (PostgreSQL)

**Utiliser** :
- `get_ecto_schemas` pour lister les schémas
- `get_docs` pour documentation modules
- `project_eval` pour tester du code Elixir
- `execute_sql_query` pour inspecter la base (READ ONLY sauf demande explicite)
