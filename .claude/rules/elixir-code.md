# Conventions de Code Elixir

## Autorisation : jamais d'assertion par match

**INTERDIT** : utiliser `true = expr` (ou tout match assertif) pour vérifier une
autorisation ou valider une donnée issue de l'utilisateur.

```elixir
# ❌ Mauvais - assertion par match
def link_prompt_to_deal(%Scope{} = scope, %Prompt{} = prompt, %Deal{} = deal) do
  true = prompt.user_id == scope.user.id
  true = deal.user_id == scope.user.id
  # ...
end
```

### Pourquoi

Un accès refusé est un cas de fonctionnement **normal**, pas un bug. Le traiter par
un crash relève de l'anti-pattern officiel « Exceptions for control-flow ».

Concrètement :

- `** (MatchError) no match of right hand side value: false` — on ignore quelle
  vérification a échoué, pour quel utilisateur, sur quelle ressource.
- L'appelant n'a aucune valeur à filtrer. Il devrait `rescue MatchError`, ce qui
  attraperait aussi les `MatchError` sans rapport venus d'ailleurs dans la pile.
- `MatchError` n'implémente pas `Plug.Exception` : en Phoenix la requête sort en
  **500, pas en 403**, et pollue le suivi d'erreurs.

### À la place

Filtrer dans la tête de fonction. Une variable répétée impose l'égalité au moment
du match ; une seconde clause transforme l'échec en valeur.

```elixir
# ✅ Bon - filtrage dans la signature
def link_prompt_to_deal(
      %Scope{user: %{id: user_id}},
      %Prompt{user_id: user_id} = prompt,
      %Deal{user_id: user_id} = deal
    ) do
  # autorisé par construction
end

def link_prompt_to_deal(%Scope{}, %Prompt{}, %Deal{}) do
  {:error, :unauthorized}
end
```

### La clause de repli reste assertive

Elle doit matcher les structs attendues (`%Scope{}, %Prompt{}, %Deal{}`), **jamais
`_, _, _`**.

```elixir
# ❌ Mauvais - avale aussi les appels mal typés
def link_prompt_to_deal(_, _, _), do: {:error, :unauthorized}
```

Un repli trop large transforme un crash utile — un appel avec les mauvais types,
qui est bien un bug — en `{:error, :unauthorized}` trompeur.

### Raisons d'échec distinctes

Quand l'appelant doit savoir *pourquoi* c'est refusé, utiliser `with` sur des
fonctions renvoyant `:ok | {:error, raison}`.

```elixir
# ✅ Bon - chaque échec porte sa raison
with :ok <- authorize_prompt(scope, prompt),
     :ok <- authorize_deal(scope, deal) do
  # ...
end
```

### Seule exception tolérée

Un invariant réellement impossible, indépendant de l'entrée utilisateur — une
donnée que la fonction a elle-même construite. Même là, préférer une garde ou un
`raise` porteur d'un message explicite.

### Détection

Le check `.credo/no_true_match.ex` existe **mais n'est pas branché** : il n'y a
aucun `.credo.exs` à la racine, donc `mix credo --strict` tourne avec les checks
par défaut et ne l'exécute pas (comme les 9 autres checks custom du dossier).

Vérifier à la main :

```bash
git grep -n "true = " -- 'lib/**/*.ex'
```

### État du code

Au 2026-09-15, 15 occurrences pré-existantes subsistent :

| Fichier | Occurrences |
|---|---|
| `lib/realtix/sphere_deals.ex` | 12 |
| `lib/realtix/teaser_shares.ex` | 3 |

`settings.ex` et `user_session_controller.ex` ont été traités par REALTIX-107.

REALTIX-99 n'avait nettoyé que le contexte `Chats`. Ne pas en ajouter de nouvelles ;
les corriger au passage quand on touche un de ces fichiers.
