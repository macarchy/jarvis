# Jarvis

Un assistant vocal bilingue (français / English) qui vit sur un seul portable,
avec Claude comme cerveau, le shell comme mains, et un poisson de Babel en
pixel art comme visage.

> **[macarchy.github.io/jarvis](https://macarchy.github.io/jarvis/index.fr.html)** — le site de documentation, avec la
> machine à états pilotable.
>
> *English: [README.md](README.md)*

```
SUPER + ALT + J          appuie pour parler, appuie encore pour la réponse
« Hey Jarvis »           pareil, sans toucher au clavier
SUPER + ALT + ESCAPE     arrête ce qui est en cours
```

Dis « mets le thème clair » et le thème change. Demande « pourquoi ma dernière
commande a échoué ? » et il lit ton historique de shell et te répond. Dis
« corrige le bug de scroll dans mon projet web » et il lance une session de
code en arrière-plan, puis vient te dire ce qu'elle a donné.

Il répond dans la langue que tu as parlée. Il se souvient d'hier. Quand il ne
peut pas faire quelque chose, il note pourquoi — et plus tard, quand il
s'ennuie, il relit ces notes et les distille en leçons qu'il garde.

---

## Est-ce que ça tournera chez toi ?

Honnêtement : **en partie**, sauf si ta machine ressemble beaucoup à la
mienne. Jarvis est fait de trois couches, et elles tombent indépendamment —
autant savoir laquelle tu récupères.

| Couche | Ce qu'elle apporte | Ce qu'elle exige |
|---|---|---|
| **La boucle vocale** | enregistrer → transcrire → réfléchir → parler : toute la conversation | Linux, PipeWire, [voxtype](https://voxtype.io), [Claude Code](https://claude.com/claude-code), Python 3 — **portable** |
| **Les mains** | changer le thème, la luminosité, le réseau, les fenêtres, lancer des applications | [Omarchy](https://omarchy.org) et Hyprland — leur CLI *est* ses mains |
| **Le corps** | le poisson dans le coin, la bulle, la barre d'écriture | [Quickshell](https://quickshell.org) via `omarchy-shell` |

La première couche tourne partout où il y a un micro. Les deux autres sont
écrites contre un bureau précis et ne prétendent pas le contraire : chaque
appel vers elles est en `|| true`, donc sur un Linux ordinaire Jarvis écoute,
réfléchit et parle toujours — il n'a simplement rien à toucher et pas de
visage à faire.

La machine de référence est un **MacBook Pro M2 sous Asahi Linux** avec
[macarchy](https://github.com/macarchy) (Omarchy plus une couche à la macOS).
`bootstrap.sh` récupère une build Piper `arm64` ou `amd64` selon l'endroit où
tu le lances.

Il te faut aussi un compte Claude : le cerveau est `claude -p`, appelé une
fois par échange. Rien d'autre dans la chaîne ne quitte la machine.

## Installation

```sh
git clone https://github.com/macarchy/jarvis.git ~/Work/jarvis
cd ~/Work/jarvis
./bootstrap.sh      # Piper, ses voix, le modèle Whisper, le venv du réveil
./install.sh        # le lien de commande, le greffon du shell, les unités
omarchy-jarvis doctor
```

`bootstrap.sh` télécharge ~300 Mo que le dépôt ne porte délibérément pas (voir
[THIRD_PARTY.md](THIRD_PARTY.md)) ; il reprend un téléchargement interrompu, et
le relancer ne récupère rien de plus. `install.sh` est idempotent lui aussi —
le relancer est la façon prévue de mettre à jour après un `git pull`.

`doctor` est la réponse à « est-ce que ça marche ? » : chaque dépendance, vert
ou rouge, sans deviner. Pour chaque ligne rouge,
[docs/troubleshooting.fr.md](docs/troubleshooting.fr.md) explique quoi faire.

`claude` et `voxtype` s'installent à part : ils ont leurs propres comptes et
leur propre configuration, ce n'est pas à Jarvis de les gérer.

## Ce qui quitte ta machine

C'est plus important que la liste des fonctions, donc c'est ici et pas en
annexe. La version longue est dans [docs/privacy.fr.md](docs/privacy.fr.md).

- **Ta parole est transcrite en local.** Whisper tourne sur ton processeur.
  L'audio ne sort jamais de la machine, et l'enregistrement est écrasé par le
  suivant.
- **Ton transcript part chez Anthropic**, puisque le cerveau est Claude. Et
  avec lui tout ce que Claude lit pour te répondre — ce qui peut inclure une
  capture d'écran ou ton presse-papier, mais **uniquement quand tu le demandes
  dans l'échange en cours**, jamais de sa propre initiative, et chaque usage
  est tracé.
- **Le daemon de réveil tient le micro ouvert** tant qu'il tourne. Il est
  optionnel (`--skip-wake`), il compare l'audio en local à un petit modèle, et
  il n'enregistre rien tant qu'il ne s'est pas déclenché.
- **Tout ce qu'il fait est écrit** dans `memory/trace/` : chaque commande,
  chaque résultat. C'est ce qui lui permet de répondre à « pourquoi as-tu fait
  ça ? ». C'est aussi un journal en clair de ta journée, sur ton disque.

Tu peux couper toute son autonomie depuis `SOUL.md` : `rondes: non` arrête
l'inspection horaire, `reves: non` la consolidation de mémoire, et
`silence: 23-7` lui donne des heures où il ne fait rien sans qu'on le lui
demande.

## Comment ça marche

Une phrase, cinq étapes, chacune avec une poignée sur disque pour pouvoir être
arrêtée :

```
appui ─▶ pw-record ─▶ voxtype (whisper) ─▶ claude -p ─▶ piper ─▶ pw-play
          record          stt                brain       voice    play
```

En dessous vit une machine à états explicite — huit états, neuf événements, et
seulement 38 des 72 couples sont légaux. Elle est dans
[`bin/jarvis-fsm.sh`](bin/jarvis-fsm.sh), écrite en prose au-dessus du code, et
gelée dans `tests/fixtures/transitions.txt` : elle ne peut pas s'éloigner de sa
propre documentation sans rendre un test rouge.

**[La machine, en pilotable](https://macarchy.github.io/jarvis/machine.fr.html)** —
appuie sur les événements, regarde le poisson changer, et regarde les coups
illégaux être refusés avec leur raison. Trente secondes là-bas valent mieux
que cette section.

Ce qui est bon à voler si tu construis quelque chose d'approchant : le fichier
d'état dit *ce que* fait la machine, et un dossier à côté dit *quelle
tentative* le fait. Chaque étape retient l'époque à laquelle elle est entrée et
se tait si elle a changé. Ça, plus le fait de lancer chaque étape externe dans
son propre groupe de processus, est ce qui rend l'annulation vraie — tuer le
groupe est ce qui atteint les sous-processus que `claude` a lancés pour ses
propres outils, ce qu'un pid nu ne fait jamais.

## Le faire tien

[`SOUL.md`](SOUL.md), c'est qui il est — le ton, l'humour, le tutoiement ou le
« monsieur », sa langue, **laquelle des trois voix françaises le porte**, ses
heures de silence, et les cinq pièces dont son poisson est assemblé. Édite-le librement ; ça s'applique à la conversation
suivante.

[`CLAUDE.md`](CLAUDE.md), c'est ce qu'il sait faire — les commandes qui sont ses
mains, écrites comme un prompt. Ajouter une capacité, c'est en général un
paragraphe là-dedans et une ligne dans `.claude/settings.json`.

« Hey Jarvis » est entraîné sur de l'anglais natif. Prononce-le à l'anglaise
(*héï djâ-vis*) ; un accent français naturel passe sous le radar du modèle. Un
clone frais n'a pas de vérificateur d'accent, donc le seuil est à `0,30` —
entraîne le tien avec `wake/train-verifier` et il monte à `0,8`.

## Développement

```sh
./tests/run        # toute la chaîne, entièrement hors ligne
```

La suite bouchonne `claude`, `piper`, `voxtype`, `pw-record`, `pw-play` et
`omarchy-shell`, et redirige l'état et la mémoire dans un bac à sable. Elle ne
prend pas le micro, ne fait aucun bruit, ne dépense aucun token et ne touche
jamais ta vraie mémoire. Si elle fait l'une de ces choses, c'est un bug.

[CONTRIBUTING.md](CONTRIBUTING.md) donne le style de la maison et les règles
qui gardent la machine honnête.

## Licence

MIT — voir [LICENSE](LICENSE). Les morceaux téléchargés ont leurs propres
licences ; [THIRD_PARTY.md](THIRD_PARTY.md) les liste.
