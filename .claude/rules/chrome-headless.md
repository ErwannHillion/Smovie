# Chrome headless : nettoyer avant de rendre la main

## La règle

**Toute session qui lance `mix test`, `mix run` ou un serveur de dev vérifie
les Chrome headless avant de terminer.**

```bash
ps -axo comm= | grep -ci "google chrome"   # combien tournent
./scripts/kill-headless-chrome.sh          # les fermer
```

## Pourquoi

`mix test` et `mix run` se terminent par un `System.halt/1`, qui ne déroule
pas l'arrêt des applications. ChromicPDF — le pool de Chrome qui sert
l'export PDF du teaser — n'a donc jamais l'occasion de refermer ce qu'il a
ouvert.

Le 2026-09-22, une journée de travail avait laissé **494 processus et
11,6 Go**. La machine ramait.

## Ce qui a été fait côté projet

| Configuration | Fuite par exécution | Durée de `pdf_exporter_test.exs` |
|---|---|---|
| Pool par défaut | ~100 processus | 18,2 s |
| `on_demand: true` | 84 processus | 18,5 s |
| Pool de taille 1 + `after_suite` | **4 processus** | **3,3 s** |

- `config/test.exs` et `config/dev.exs` : `on_demand: false, session_pool: [size: 1]`
- `config/config.exs` : `on_demand: false` — la production garde un pool chaud
- `test/test_helper.exs` : `Supervisor.stop(Realtix.Supervisor)` dans
  `ExUnit.after_suite/1`, suivi d'un court délai

**Ne pas remettre `on_demand: true`** : ce mode ouvre un Chrome *par
opération*, hors de l'arbre de supervision, donc l'arrêt de fin de suite ne
les voit pas. C'est pire que le pool, et cinq fois plus lent.

## Le piège du filtre

Le navigateur interactif et le headless partagent le même binaire. Un
`pkill -f "Google Chrome"` emporterait les onglets de l'utilisateur.

❌ `pkill -f "Google Chrome"`
❌ `pgrep -fa` — tronque les lignes de commande, le comptage est faux
❌ `ps ... | grep -- '--headless'` — attrape sa propre ligne de commande

✅ Filtrer sur le binaire **et** sur le drapeau :

```bash
ps -axo pid=,args= | awk '/Google Chrome\.app/ && /--headless/ {print $1}'
```
