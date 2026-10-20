Lance une revue de code sur les changements (working tree / branche courante), **à deux niveaux** : ciblé sur la feature ET élargi au contexte réel. Ne pas se contenter du diff isolé.

Avant de lancer les agents : faire `git diff` (+ `git status`, et lire en entier tout NOUVEAU fichier) pour connaître le périmètre exact, puis lancer les agents **en parallèle** (plusieurs `Agent` dans un seul message).

---

## Niveau 1 — Revue ciblée (le diff / la feature)

**Agent Code Review** — conformité aux règles projet (`.claude/rules/`), pattern matching, nommage, idiomes Elixir/Phoenix, docstrings, gestion des cas limites (nil, "", map partielle, données absentes), cohérence string/atom, `Application.get_env` vs `System.get_env`, pas de valeur en dur.

**Agent Performance** — N+1, requêtes dans une boucle, preload manquant, transactions manquantes, coût au render, chargement paresseux, `phx-debounce`/`phx-throttle` sur les events fréquents (sliders, recherche), optimisations mount LiveView. Distinguer vrais problèmes et optimisations prématurées.

**Agent Database Safety** — migrations, upserts (`on_conflict`), idempotence, seeds **base ↔ réconciliation** (un champ ajouté doit être dans le mapping base + le seed base + un NOUVEAU seed de réconciliation, sinon `KeyError` sur DB fraîche), `Repo.all` vs `Repo.one` (doublons historiques), chemins de crash (`FunctionClauseError`, `String.to_integer` sur `""`, `retrieve_types` sur `nil`), non-écrasement des données webadmin existantes.

## Niveau 2 — Revue élargie (contexte & usage réel) — NE PAS OMETTRE

**Agent Intégration & usage réel** — c'est ici qu'on attrape ce qu'une revue au niveau du fichier rate. Analyser le code **dans son environnement**, pas isolément :

- **Interactions inter-composants** : tracer les composants/LiveViews voisins. Un composant vit-il dans un `<.form phx-change/phx-submit>` parent ? sous une modale (`close_on_escape`, focus trap) ? est-il abonné à un topic PubSub dont le `handle_info` fourre-tout réassigne l'état ? Une instance de `live_component` peut-elle être **réutilisée** entre deux contextes (id non unique) et garder un état figé → écrasement silencieux ? Un input émet-il un event qui **remonte/sérialise** le form parent (`phx-change` → `serializeForm(inputEl.form)`) au lieu d'envoyer ce qu'on croit ?
- **Gestes utilisateur réels** : ne pas se limiter à « le diff compile ». Passer en revue **Entrée** (soumission implicite de form), **Échap** (fermeture de la modale parente), **coller / autofill / drag-drop** (émettent `input`, pas `keyup`), **navigation A→B**, focus/clavier, accents dans une recherche. Ces bugs n'apparaissent qu'en simulant l'usage.
- **Réutilisation de l'existant (ne pas réinventer)** : chercher dans `lib/` si un helper / composant / pattern couvre déjà le besoin (ex. `render_media_thumbnail`, `render_span_title_with_color`, `sanitize_string`, `button_helper`, `ColorHelper`) avant d'en écrire un nouveau. Le code est-il cohérent avec la convention majoritaire du repo (mêmes noms de champs, même mécanisme couleur/bouton/badge que les autres sections) ?
- **Historique & régression d'affordance** : le changement **contredit-il un commentaire ou un fix antérieur** (ex. re-crée l'état « vide corrompu » de CORPO-621) ? **Perd-il un comportement** de l'ancienne implémentation qu'il remplace (une option du `<select>`, un avertissement « format non supporté », un tri, une info affichée) ? Laisse-t-il un commentaire devenu faux ?
- **Piloter le flux réel** quand c'est faisable : pour une feature UI, monter un harnais `live_isolated` / LiveViewTest qui **dispatche vraiment** les events (open/search/submit/clear) plutôt que d'asserter sur un rendu statique — sinon la logique (`load_media`, `visible_files`, filtrage) n'est jamais exécutée sous test.

---

## Consignes transverses (pour tous les agents)

- **Ne pas rester au niveau du fichier** : suivre les appelants, les composants voisins, le layout, le routeur.
- **Ne pas balayer un ⚠️ comme « théorique »** sans tracer le pire scénario concret (qui/quand/quel effet).
- **Vérifier avant d'affirmer** : ouvrir le vrai code / la vraie donnée plutôt que supposer.
- Chaque agent commence par `git diff` sur son périmètre et lit le contexte nécessaire. Aucun agent ne modifie de fichier.

## Rapport à présenter (synthèse consolidée)

Regrouper les findings des deux niveaux, dédupliqués, classés par gravité :
- ✅ **Points conformes**
- ⚠️ **Suggestions d'amélioration** (préciser si feature-local ou contexte/usage)
- ❌ **Problèmes critiques à corriger** (avec `fichier:ligne` et le scénario d'échec concret)

Indiquer explicitement ce qui relève du **niveau 1 (feature)** vs **niveau 2 (contexte/usage réel)**, et signaler les recoupements. Utile avant une PR ou après modification de code existant.

## APRÈS le rapport — NE RIEN APPLIQUER SANS ACCORD

`/review` s'arrête au **rapport**. Ne PAS corriger, éditer ou commiter quoi que ce soit avant d'avoir présenté les findings et **laissé l'utilisateur décider**.

- Présenter le topo d'abord. Chaque finding (même un ❌) peut être **non pertinent, hors périmètre, ou à traiter autrement** — c'est le choix de l'utilisateur, pas le mien.
- Terminer le rapport par une question du type : « lesquels je corrige ? » et attendre la réponse.
- N'appliquer un correctif que sur demande explicite (ou si l'utilisateur avait dit d'avance « corrige au fil de l'eau »).
- Ne jamais enchaîner review → fix → topo. C'est : review → **topo → attendre** → (éventuellement) fix.
