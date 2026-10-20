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

Le check `.credo/no_true_match.ex` est branché par `.credo.exs` depuis SMOVIE-001 :
`mix credo --strict` l'exécute, comme les neuf autres checks du dossier.

Vérification manuelle d'appoint :

```bash
git grep -n "true = " -- 'lib/**/*.ex'
```

### État du code

Zéro occurrence. La refonte repart d'une base propre : il ne s'agit pas d'une dette à
résorber mais d'une règle à ne pas enfreindre.
