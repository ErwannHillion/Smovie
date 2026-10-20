# Chrome headless : nettoyer avant de rendre la main

## La règle

**Toute session qui lance un Chrome headless le referme avant de terminer.**

```bash
ps -axo comm= | grep -ci "google chrome"   # combien tournent
./scripts/kill-headless-chrome.sh          # les fermer
```

## Pourquoi

Un Chrome headless lancé en ligne de commande, ou par une bibliothèque qui gère son
propre pool, ne se referme pas toujours quand le processus parent s'arrête — `mix test`
et `mix run` se terminent par un `System.halt/1`, qui ne déroule pas l'arrêt des
applications. Les instances s'accumulent, silencieusement, à plusieurs centaines de
mégaoctets pièce.

Sur un autre projet de l'équipe, une journée de travail avait laissé **494 processus et
11,6 Go**.

## Le piège du filtre

Le navigateur interactif et le headless partagent le même binaire. Un
`pkill -f "Google Chrome"` emporterait les onglets de l'utilisateur.

❌ `pkill -f "Google Chrome"` — tue la session interactive
❌ `pgrep -fa` — tronque les lignes de commande, le comptage est faux
❌ `ps ... | grep -- '--headless'` — attrape sa propre ligne de commande

✅ Filtrer sur le binaire **et** sur le drapeau :

```bash
ps -axo pid=,args= | awk '/Google Chrome\.app/ && /--headless/ {print $1}'
```

## Si un pool est introduit un jour

Smovie n'embarque pas ChromicPDF aujourd'hui. Si un export PDF arrive :

- configurer `on_demand: false` avec `session_pool: [size: 1]` en `test` et en `dev` —
  `on_demand: true` ouvre un Chrome **par opération**, hors de l'arbre de supervision,
  donc l'arrêt de fin de suite ne les voit pas ;
- arrêter le superviseur applicatif dans `ExUnit.after_suite/1`.
