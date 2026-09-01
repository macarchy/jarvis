---
layout: default
lang: fr
alt: /troubleshooting.html
altlang: en
title: Quand quelque chose est rouge
description: Une entrée par ligne que `omarchy-jarvis doctor` peut afficher, dans l'ordre où il les affiche.
---

# Quand quelque chose est rouge

`omarchy-jarvis doctor` nomme chaque dépendance, verte ou rouge, sans deviner
et sans faire appel au moindre modèle. Son code de sortie est le nombre de
problèmes. Cette page donne une entrée par ligne qu'il peut afficher, dans
l'ordre où il les affiche.

Lancez-le d'abord. Tout ce qu'il déclare correct l'est.

```sh
omarchy-jarvis doctor          # la vérification complète
omarchy-jarvis doctor --mic    # avec une vraie capture d'une demi-seconde
omarchy-jarvis doctor --quiet  # seulement les lignes rouges
```

---

### ✗ claude (le cerveau)

Claude Code n'est pas installé, ou pas dans le `PATH`. Installez-le depuis
[claude.com/claude-code](https://claude.com/claude-code) et connectez-vous —
Jarvis ne manipule jamais vos identifiants, il lance simplement `claude -p`.

Vert mais il dit quand même « Je n'ai pas pu joindre mon cerveau » ? Regardez
`omarchy-jarvis status | grep brain`. `quota <epoch>` signifie que vous avez
atteint une limite d'usage et qu'il repartira tout seul ; `down` signifie que
le dernier appel a échoué. La raison est dans `memory/trace/<aujourd'hui>.log`.

### ✗ voxtype (l'oreille)

Le transcripteur manque. Installez-le depuis [voxtype.io](https://voxtype.io).
C'est un projet à part, avec sa propre configuration ; Jarvis se contente
d'écrire une configuration dérivée avec la langue épinglée, puis de l'appeler.

Installé mais il ne transcrit rien ? Le modèle Whisper est probablement
absent — `./bootstrap.sh` place `ggml-small.bin` dans
`~/.local/share/voxtype/models/`.

### ✗ pw-record / ✗ pw-play

Les outils en ligne de commande de PipeWire manquent. Sur Arch ils sont dans
`pipewire` lui-même ; ailleurs, cherchez un paquet `pipewire-tools` ou
`pipewire-utils`. Il n'y a pas de repli vers ALSA ou PulseAudio.

### ✗ piper : une synthèse réelle

Cette vérification ne teste pas la présence du fichier — elle **synthétise
vraiment** une courte phrase, parce qu'un modèle de voix tronqué par un disque
plein est présent, exécutable, et muet. Relancez `./bootstrap.sh` ; il ne
récupère que ce qui manque ou ce qui est cassé.

Vérifiez aussi la place disponible : les modèles font 60 Mo chacun et un
téléchargement partiel est la cause classique.

### ✗ voix anglaise

`models/en_GB-alan-medium.onnx` manque. `./bootstrap.sh`.

La voix française, elle, est couverte par la synthèse réelle ci-dessus. Laquelle
des trois parle est un réglage de l'âme (`voix: siwis | tom | upmc`) ;
`bootstrap.sh` ne télécharge que celle que l'âme demande, donc changer ce
réglage demande de relancer `./bootstrap.sh` une fois.

### ✗ micro (…) présent

Jarvis enregistre depuis un nœud nommé plutôt que depuis la source par défaut
du système, parce qu'on a vu cette dernière partir vers une webcam en pleine
session. Le nom est `effect_output.j493-mic` — un nœud propre à Asahi qui
n'existera pas chez vous.

Listez les vôtres et épinglez le bon :

```sh
pactl list sources short
export JARVIS_MIC=alsa_input.pci-0000_00_1f.3.analog-stereo
```

Fixez-le durablement dans les unités systemd, ou laissez `JARVIS_MIC` vide — si
le nœud nommé est absent, Jarvis retombe sur la source par défaut du système,
ce qui est en général le bon choix.

### ✗ micro : capture réelle *(seulement avec `--mic`)*

Le nœud existe mais n'enregistre que du silence. Vérifiez qu'il n'est pas coupé
(`wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0`), que rien d'autre ne le tient en
exclusivité, et que le portail de votre bureau ne bloque pas l'accès.

### ✗ daemon wake (hey Jarvis)

Le daemon de réveil ne tourne pas. Il est optionnel — la touche « appuyer pour
parler » fonctionne sans lui — et il démarre depuis l'autostart de votre
compositeur :

```lua
o.exec_on_start("omarchy-jarvis-wake")   -- ~/.config/hypr/autostart.lua
```

Lancez-le tout de suite avec `omarchy-jarvis-wake &`. S'il ressort aussitôt en
disant `already running`, c'est qu'une autre copie tient le verrou ; c'est la
vérification qui fait son travail.

**Il n'entend pas son nom.** Le modèle est entraîné sur de l'anglais natif.
Prononcez *héï djâ-vis*, à l'anglaise. Un clone frais n'a pas de vérificateur
d'accent, donc le seuil est à `0,30` ; la trace des scores est dans
`$XDG_RUNTIME_DIR/jarvis/wake-score`, et `JARVIS_WAKE_THRESHOLD` le remplace.
Entraînez un vérificateur sur votre propre voix avec `wake/train-verifier` et
il monte à `0,8`, avec bien moins de faux positifs.

### ✗ venv wake + openwakeword

`./bootstrap.sh` construit `wake/venv`. S'il a échoué, la cause habituelle est
qu'`onnxruntime` n'a pas de roue pour votre version de Python — construisez le
venv contre un interpréteur plus ancien :

```sh
rm -rf wake/venv && python3.12 -m venv wake/venv
wake/venv/bin/pip install openwakeword onnxruntime numpy scikit-learn joblib
```

### ✗ planches du poisson / ✗ poisson conforme à l'âme

Les planches de sprites manquent, ou elles ne correspondent plus aux cinq
réglages d'apparence de `SOUL.md`. Les deux tiennent en une commande :

```sh
omarchy-jarvis look           # régénérer depuis l'âme
omarchy-jarvis look random    # tirer un nouveau poisson d'abord
```

Les planches vivent dans `~/.local/share/jarvis/sprites/`, délibérément en
dehors du dossier des greffons — le shell s'y recharge à la moindre
modification.

### ✗ greffon installé

Le greffon du mascotte n'est pas dans `~/.config/omarchy/plugins/`. Lancez
`./install.sh`, puis `omarchy plugin enable macarchy.jarvis`.

Cette ligne est censée être rouge si vous ne faites pas tourner Omarchy et
Quickshell. Rien d'autre ne casse : le poisson est la couche *corps*, et chaque
appel vers elle est en `|| true`.

### ✗ unités systemd installées et actives

Les unités utilisateur manquent ou sont arrêtées. `./install.sh` les installe
et les active. Pour vérifier à la main :

```sh
systemctl --user is-active jarvis-tick.timer jarvis-inbox.path
systemctl --user list-timers jarvis-tick.timer
```

`jarvis-tick.timer` est le pouls — le chien de garde, les rondes, les rêves, la
rotation de conversation et les reprises de la boîte d'entrée en dépendent
toutes. Sans lui, tout cela s'arrête dès que quoi que ce soit se fige.
`jarvis-inbox.path` surveille `~/Jarvis/input`.

### ✗ omarchy-jarvis pointe sur ce dépôt

`~/.local/bin/omarchy-jarvis` résout vers autre chose — en général un second
clone. Quel que soit celui que vous vouliez, lancez son `./install.sh`.

### ✗ boîte … / ✗ symlink memory

`~/Jarvis` manque, ou son lien `memory` ne pointe pas vers le `memory/` de ce
clone. N'importe quelle commande Jarvis recrée la boîte ; le lien, c'est
`ln -s <clone>/memory ~/Jarvis/memory`.

### ✗ settings.json valide

`.claude/settings.json` n'est pas du JSON valide, ce qui signifie que le
cerveau tourne **sans aucune** liste d'autorisations. Réparez-le avant de lui
reparler :

```sh
python3 -m json.tool .claude/settings.json
```

### ✗ prompts (ronde, rêve, digestion)

Un des fichiers `memory/HEARTBEAT_PROMPT.md`, `DREAM_PROMPT.md` ou
`DIGEST_PROMPT.md` manque. Ils sont suivis par git ; `git checkout memory/` les
restaure.

### ✗ connaissance à jour (omarchy)

`memory/knowledge/` a été généré contre un Omarchy plus ancien. Il se
reconstruit par introspection, sans aucun modèle :

```sh
omarchy-jarvis index
```

Le pouls le fait automatiquement après une mise à jour d'Omarchy.

---

## Ce que doctor ne peut pas voir

**Il est bloqué.** `omarchy-jarvis state` dit `thinking` et rien ne bouge.
Appuyez sur la touche — pendant la transcription ou la réflexion, elle annule.
Ou bien :

```sh
omarchy-jarvis cancel
omarchy-jarvis watchdog    # ce que le pouls lance toutes les 60 s
```

`doctor` signale comme un problème un état vieux de plus de dix minutes, avec
la commande pour le libérer.

**Il répond à une pièce vide.** Whisper hallucine sur du silence — « Sous-titres
réalisés par la communauté d'Amara.org » est le grand classique. Montez
`JARVIS_WAKE_THRESHOLD`, ou entraînez le vérificateur d'accent pour que le mot
de réveil cesse de se déclencher sur le bruit ambiant.

**Il parle dans la mauvaise langue.** Le réglage `langue` de `SOUL.md` fixe
la conversation entière — ce que ses oreilles attendent et la voix qui répond.
Épinglez-le sur `fr` ou `en` plutôt que de le laisser sur `auto` : sous `auto`
il devine, une fois par réponse, et la détection n'est pas fiable sur les
phrases courtes. Le Control Center le règle d'un clic, et le changement
s'applique à la phrase suivante.

**Rien ne se passe du tout sur la touche.** Vérifiez que la liaison a bien
atteint le compositeur : `hyprctl binds | grep -A2 jarvis`. Une liaison modifiée
dans `~/.config/hypr/bindings.lua` demande un rechargement de la configuration
avant d'exister.

## Toujours bloqué

Ouvrez une issue avec la sortie de `omarchy-jarvis doctor`. Si le problème est
comportemental plutôt que structurel, `memory/trace/<date>.log` est la boîte
noire — **relisez-la avant de la coller**, c'est un journal de votre machine.
