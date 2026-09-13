# codex-local

Scripts, templates et notes d'expérimentation pour faire tourner l'outil **OpenAI Codex CLI** (`--oss`) avec un grand modèle local (Qwen3.8-27B) sur Mac Apple Silicon (M1/M2/M3/M4) via `llama-server`.

> ⚠️ **Statut : Expérimental / Bricolage technique.**  
> Ce n'est ni du "clé en main pour la prod", ni un remplaçant magique des API cloud. C'est un banc d'essai pour voir jusqu'où on peut pousser l'inférence locale pour du code sur 16 Go à 32 Go de mémoire unifiée sans que la machine ne s'effondre.

---

## Pourquoi ce repo ?

Par défaut, pointer Codex CLI vers un modèle local 27B (via Ollama ou autre) pose plusieurs problèmes concrets :

1. **Trop lent par défaut (~8-10 tok/s)** : Lire 16 Go de poids à chaque token sature la bande passante mémoire.
2. **Ingestion de prompt délirante (85 000 tokens)** : Codex envoie toutes les définitions de plugins/apps au démarrage. Sur un modèle local, ça prend des plombes avant même de taper la première ligne.
3. **Fuite des balises XML (`<think>`, `<tool_call>`)** : Le template ChatML basique renvoie les appels d'outils et les réflexions en texte brut dans la réponse, donc Codex ne déclenche pas les commandes shell/fichiers.
4. **Plantages multi-tours** : Le template Jinja standard de Qwen lève une exception (`System message must be at the beginning`) dès que Codex injecte du contexte en cours de route.

Ce dépôt rassemble les correctifs trouvés pour contourner ces blocages.

---

## Ce qui est mis en place

- **Modèle compacté + MTP** : Utilisation d'un checkpoint quantifié en GSQ-RCO (~11 Go) intégrant une tête MTP (*Multi-Token Prediction*). Avec `llama-server` et `--spec-type draft-mtp --spec-draft-n-max 2`, on monte autour de 30-40 tok/s sur M1 Max quand le décodage spéculatif accroche (taux d'acceptation de 70 à 90%).
- **Cache KV compressé (`q4_0`)** : Réduit l'empreinte mémoire du contexte 64k de ~16 Go à ~4 Go, évitant le swap sur Mac 32 Go.
- **Régime sur le prompt Codex** : Dans `config.toml`, désactivation des plugins/apps non utilisés pour passer de 85k à ~4.8k tokens d'ingestion.
- **Template Jinja sur mesure (`templates/template.jinja`)** : Formate les outils pour que `llama-server` (avec `--reasoning-format deepseek`) sépare proprement `reasoning_content` et les vrais `tool_calls` JSON attendus par Codex.
- **Wrapper CLI (`bin/codex-local`)** : Script bash qui vérifie si `llama-server` tourne, le lance en tâche de fond si nécessaire, attend qu'il réponde sur le port 1234, puis passe la main à Codex.

---

## Modèles : Aligné vs Uncensored

> ⚠️ **Attention au nom du modèle :**  
> Le fichier téléchargé par défaut dans le script d'installation (`ISTA-DASLab/Qwen3.8-27B-GSQ-RCO-GGUF`) est la version **officielle Qwen3.8-27B-Instruct**, donc **alignée et censurée** (elle refuse les insultes, harcèlement, etc.).
>
> Même si l'alias porte le suffixe `uncensored` par commodité de configuration locale, les poids sous-jacents restent ceux d'Alibaba. Si vous cherchez un vrai modèle abliteré/sans garde-fous avec MTP, il faut pointer vers des variantes communautaires non censurées (ex. `RentedNoodle/Qwen3.8-27B-GSQ-RCO-IQ3_XXS-Uncensored` ou `HauhauCS`).

---

## Utilisation

### Prérequis
- Mac Apple Silicon (M1/M2/M3/M4) avec 16 Go de RAM minimum (32 Go fortement recommandés).
- `brew install llama.cpp`
- OpenAI Codex CLI installé.

### Installation
```bash
git clone https://github.com/jhiver/codex-local.git
cd codex-local
./install.sh
```

### Lancer Codex
```bash
codex-local
```

### Commandes utiles
```bash
codex-local status   # État du serveur et modèle chargé
codex-local logs     # Suivre les logs (vitesse, acceptance MTP)
codex-local stop     # Couper le serveur d'arrière-plan
codex-local start    # Démarrer le serveur seul
```

---

## Limites connues

- **Support OSS Codex instable** : Le mode `--oss` de Codex CLI est encore expérimental côté OpenAI, le comportement des métadonnées et des appels d'outils peut changer d'une version à l'autre.
- **Qualité du code** : Un modèle 27B local reste très inférieur à GPT-5 / Claude 3.7 / Opus sur les refactors complexes ou les longs contextes.
- **Conflits de RAM** : Si Ollama ou une autre app GPU tourne en parallèle, Metal refusera d'allouer la mémoire (penser à `brew services stop ollama`).

---

## Licence

MIT
