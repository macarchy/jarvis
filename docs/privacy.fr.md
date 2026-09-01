---
layout: default
lang: fr
alt: /privacy.html
altlang: en
title: Ce que Jarvis sait, garde et envoie
description: Le compte rendu franc de ce qui quitte votre machine, de ce qui est conservé, et de comment couper chaque partie.
---

# Ce que Jarvis sait, garde et envoie

Jarvis tient un microphone ouvert, lit votre écran quand on le lui demande, et
confie vos mots aux serveurs d'une entreprise. Ça mérite un compte rendu franc
plutôt qu'un paragraphe rassurant. Tout ce qui suit est vérifiable dans le code
source ; le fichier et la ligne sont nommés pour que vous n'ayez pas à croire ce
document sur parole.

## La version courte

| | Où ça va | Conservé |
|---|---|---|
| Votre audio | nulle part — transcrit sur votre processeur | écrasé par l'énoncé suivant |
| Votre transcript | **Anthropic**, comme prompt | dans `memory/journal/`, sur votre disque |
| Sa réponse | vos haut-parleurs | idem |
| Une capture d'écran | **Anthropic**, seulement si vous le demandez dans l'échange | `~/.cache/jarvis/screen.png`, écrasée |
| Votre presse-papier | **Anthropic**, seulement si vous le demandez | pas conservé à part |
| Chaque commande qu'il lance | nulle part | `memory/trace/<date>.log`, sur votre disque |

## L'audio ne quitte jamais la machine

`pw-record` écrit un seul WAV dans `$XDG_RUNTIME_DIR/jarvis/utterance.wav`.
`voxtype` — Whisper, tournant en local sur votre processeur — le transforme en
texte. L'enregistrement suivant écrase le fichier, et `$XDG_RUNTIME_DIR` est
vidé à la déconnexion. Aucun audio n'est envoyé, à aucun moment, par aucune
partie de ce système.

La réponse synthétisée suit la même règle : Piper tourne en local, et le WAV
qu'il produit vit à côté de l'enregistrement jusqu'à ce que le suivant le
remplace.

## Le transcript part chez Anthropic

Le cerveau est [Claude Code](https://claude.com/claude-code), appelé comme
`claude -p` une fois par échange (`bin/jarvis:627`). Ce qu'il reçoit :

- ce que vous avez dit, en texte ;
- `CLAUDE.md` et `SOUL.md` — ses instructions et sa personnalité ;
- `memory/LEARNED.md` — les leçons que ses rêves ont distillées ;
- `memory/CONVERSATION.md` — le résumé de la dernière conversation close ;
- la conversation en cours, reprise d'un échange à l'autre par un identifiant
  de session ;
- et tout ce qu'il lit *pendant* qu'il vous répond, qui fait l'objet de la
  section suivante.

Ce qu'Anthropic en fait, c'est à eux de l'énoncer, pas à ce projet. Si ce n'est
pas acceptable pour ce que vous vous apprêtez à dire, la réponse est de ne pas
le dire à Jarvis.

## Ce qu'il peut lire, et quand

Ses outils sont une liste d'autorisations explicite dans
`.claude/settings.json` — si une commande n'y figure pas, l'appel est refusé.
Celles qui touchent à vos données :

- **`grim`** — une capture d'écran, vers `~/.cache/jarvis/screen.png`, qu'il lit
  ensuite. Uniquement sur demande explicite dans l'échange en cours (« résume
  cette page »), jamais de sa propre initiative, et jamais pendant une ronde
  autonome ou un rêve. `CLAUDE.md` énonce cette règle ; la boîte noire trace
  chaque usage.
- **`wl-paste`** — votre presse-papier, aux mêmes conditions.
- **`hyprctl activewindow`** — la classe et le titre de la fenêtre active.
- **`sqlite3` sur l'historique d'atuin** — votre dernière commande shell, son
  code de sortie et sa durée.
- **`WebSearch`** — pour les questions dont la réponse n'est pas sur cette
  machine. Votre requête sort ; c'est ce qu'est une recherche.

Tout ce qu'il lit ainsi devient une partie du prompt de ce tour, et part donc
chez Anthropic avec lui.

## Deux choses qui tournent sans surveillance

**Les missions de fond.** `omarchy-jarvis dispatch` lance un `claude -p`
détaché avec `--permission-mode acceptEdits` dans un répertoire que vous
nommez (`bin/jarvis:1039`). Cette session **modifie des fichiers sans
demander**. C'est comme ça que « corrige le bug de scroll dans mon projet »
fonctionne, et c'est la chose la plus puissante ici. Elle est déclenchée par
votre parole, et toute son exécution est journalisée dans
`~/.local/state/jarvis/missions/`.

**La boîte d'entrée.** Un fichier déposé dans `~/Jarvis/input` est lu par une
session sans Bash, sans Edit et sans Task — un document qu'on vous a donné est
de la *donnée citée*, jamais une consigne à suivre. `CLAUDE.md` le dit
explicitement, parce qu'un document qui demande à être obéi est une vraie
attaque et que le confinement en est la vraie défense. Un lien seul dans un
fichier `.url` reçoit en plus `WebFetch`, et récupérer une page indique à ce
serveur que vous l'avez récupérée.

## La boîte noire

`memory/trace/<date>.log` enregistre chaque commande que Jarvis a lancée et ce
qui en est revenu. C'est ce qui lui permet de répondre à « pourquoi as-tu fait
ça ? », et c'est là que ses rêves trouvent la cause racine d'un échec. C'est
aussi, inévitablement, un journal en clair de votre journée : le thème que vous
avez changé, le fichier sur lequel vous l'avez interrogé, l'erreur que vous
avez collée.

Il reste sur votre disque et n'est jamais envoyé nulle part de lui-même — mais
il est cité dans son contexte quand on lui demande de s'expliquer, et c'est le
fichier à nettoyer avant de coller quoi que ce soit dans un rapport de bug.

Les voisins : `memory/journal/` (une ligne par échange), `memory/FAILURES.md`
(ce qu'il n'a pas pu faire), `memory/ABORTS.md` (ce que vous avez interrompu),
`~/.local/state/jarvis/jarvis.log` (le journal de développement).

Aucun de ces fichiers n'est suivi par git. Le dépôt ne porte que leurs
en-têtes, dans `memory/scaffold/`, et ils sont restaurés vides sur un clone
frais — donc rien de ce que vous pouvez dire à Jarvis ne se retrouve dans un
commit par accident.

## Le microphone, quand vous ne parlez pas

Le daemon de réveil (`bin/jarvis-wake.py`) tient le microphone ouvert pendant
toute sa vie, par trames de 80 ms, et compare chacune à un petit modèle local.
Rien n'est écrit et rien n'est envoyé tant qu'il ne s'est pas déclenché. Il est
optionnel à l'installation (`./bootstrap.sh --skip-wake`), et vous pouvez
l'arrêter à tout moment :

```sh
pkill -f jarvis-wake.py && omarchy-jarvis settle
```

La touche « appuyer pour parler » continue de fonctionner sans lui.
`omarchy-jarvis doctor` vous dit honnêtement s'il tourne.

## Baisser son autonomie

Tout est dans [`SOUL.md`](https://github.com/macarchy/jarvis/blob/main/SOUL.md),
et ça prend effet à la conversation suivante :

```
rondes: non        aucune inspection horaire de la machine
reves: non         aucune consolidation de mémoire quand il s'ennuie
silence: 23-7      les heures où il ne fait rien sans qu'on le lui demande
```

Pour arrêter complètement le pouls autonome :

```sh
systemctl --user disable --now jarvis-tick.timer jarvis-inbox.path
```

Il ne fait alors plus rien du tout tant que vous n'appuyez pas sur la touche.

## Effacer ce dont il se souvient

```sh
omarchy-jarvis reset                       # oublier la conversation en cours
rm -rf memory/trace memory/journal         # oublier ce qu'il a fait
: > memory/LEARNED.md                      # oublier ce qu'il a appris de vous
rm -rf ~/.local/state/jarvis               # oublier sa propre santé et ses repères
```

Rien ici n'est synchronisé où que ce soit. Supprimer les fichiers, c'est toute
la procédure.
