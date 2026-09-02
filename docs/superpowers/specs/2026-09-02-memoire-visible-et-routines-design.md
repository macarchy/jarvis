# Mémoire visible et routines — design

Date : 2026-09-02. Trois manques relevés par l'utilisateur : effacer son
dernier message, voir ce qui s'est passé dans la tête de Jarvis, voir les
conversations ; et des tâches planifiées configurables. Décision : pas
d'application séparée — des verbes CLI qui lisent ce qui existe déjà, une
seconde fenêtre du plugin `macarchy.jarvis`, et un fichier de routines lu
par le pouls.

## Faits vérifiés

- La conversation est un transcript Claude Code :
  `~/.claude/projects/-home-phmatray-Work-jarvis/<session>.jsonl`, une
  ligne JSON par événement (`user`, `assistant` avec blocs `thinking`,
  `text`, `tool_use`, `tool_result` ; `last-prompt` en fin de fichier).
  Chaque message porte `uuid`/`parentUuid`.
- Déplacer `leafUuid` ne fait rien oublier ; tronquer le fichier après la
  dernière réponse complète, si : la copie tronquée reprise par `--resume`
  ne connaît plus l'échange suivant (testé sur copie, 2026-09-02).

## Verbes (bin/jarvis) et l'aide python bin/jarvis-transcript

`CLAUDE_PROJECTS="${JARVIS_CLAUDE_PROJECTS:-$HOME/.claude/projects}"`,
dossier de projet = `$JARVIS_DIR` avec `/` → `-`. La session courante est
`$CONV_FLAG`.

- `omarchy-jarvis undo [--quiet]` — oublie le dernier échange de la
  conversation courante. Refusé (exit 1, phrase dite) si la machine n'est
  pas `idle`/`sleeping`, s'il n'y a pas de conversation, ou plus d'échange.
  Sauvegarde du transcript dans `$STATE_DIR/undo/<session>-<epoch>.jsonl`,
  troncature avant le dernier tour `user` textuel, `last-prompt` réécrit.
  Retire la dernière ligne `échange : « … »` du journal du jour, remet la
  paire last-ask/last-reply sur l'échange précédent (ou les efface),
  trace « — dernier échange oublié — », bulle vidée, dit « Oublié. »
- Voix : dans le chemin d'écoute, après `is_noise`, `is_undo "$text"`
  (« oublie ce que je viens de dire », « efface mon dernier message »,
  « annule ma dernière question », "forget what I just said", "delete my
  last message") lance `undo` sans passer par le cerveau.
- `omarchy-jarvis transcript [--json] [--session <id>] [n]` — les n
  derniers échanges (défaut 5). Texte : `HH:MM « question »`, lignes
  `  ✎ pensée` (réflexion, tronquée à 300 car.), `  → Outil: détail`,
  `  ← résultat` (200 car.), `  ✗ erreur`, puis `  ⇒ réponse`. JSON :
  `[{at, ask, reply, thoughts:[…], tools:[{call, result, error}]}]`.
- `omarchy-jarvis conversations [--json]` — les sessions du dossier de
  projet, la plus récente d'abord : `id\tdébut\tfin\tn\tpremière question`,
  `*` en tête de la courante. JSON : `[{id, current, started, ended,
  exchanges, first}]`.
- `omarchy-jarvis routines [--json]` / `routine <n> on|off|delete` /
  `routine add "<ligne>"` — voir ci-dessous.

## Routines : memory/ROUTINES.md

Une ligne par routine, éditable à la main, par le Control Center, et par
Jarvis à la voix (Edit(memory/**) est déjà autorisé ; fiche
memory/skills/routines.md + règle dans CLAUDE.md).

```
- 08:00 lun-ven ask --quiet Briefing du matin : agenda, mails, batterie
- 18:30 * say Pense à brancher le Mac.
- 2026-09-03 15:00 once say Appeler Marc.
- off 03:00 dim dispatch Nettoie ~/Jarvis/output des exports de plus de 30 jours
```

Grammaire : `- [off] (HH:MM <jours> | AAAA-MM-JJ HH:MM once) <verbe> <texte>`.
Jours : `*`, `lun`…`dim`, plages `lun-ven`, listes `lun,mer`. Verbes :
`say`, `ask`, `ask --quiet`, `notify`, `dispatch`.

Exécution par `tick` (chaque minute, sous son verrou), après le bilan de
santé et AVANT la sortie des heures de silence : `jarvis-routines due`
imprime les routines dues — heure prévue dans les 10 dernières minutes et
tampon `$STATE_DIR/routines/<n°-de-ligne-hash>` antérieur à cette heure.
Une machine endormie rattrape donc dans les 10 minutes, sinon saute et
journalise « routine sautée ». Heures de silence : `say`/`ask` deviennent
`notify`/`ask --quiet`. Cerveau en quota : `ask`/`dispatch` sautés et
journalisés. `once` est retirée du fichier après tir. Chaque tir écrit
« routine : <ligne> » au journal et à la trace.

`status` ajoute `routines=<n actives>` et `next_routine=<epoch>`.

## Fenêtre Journal (plugin macarchy.jarvis, Service.qml)

IPC `omarchy-shell macarchy.jarvis journal` (toggle), `journalClose`.
PanelWindow `macarchy-jarvis-journal`, couche Top, focus clavier OnDemand
(Échap ferme), ancrée en haut à droite sous la barre, ~520×700 px, style
papier du philactère (`#FFF8E6` / encre `#181208`). Trois onglets :

1. **Aujourd'hui** — `transcript --json 30` de la conversation courante :
   par échange, l'heure, la question, la réponse, un repli « dans sa
   tête » (pensées puis outils). Sur le dernier échange, un bouton
   « Oublier » → `omarchy-jarvis undo --quiet`, puis rechargement.
2. **Conversations** — `conversations --json` ; clic sur une ligne charge
   `transcript --json --session <id> 50` dans le même rendu (sans
   « Oublier »).
3. **Routines** — `routines --json` : une ligne par routine avec
   interrupteur (`routine <n> on|off`) et corbeille (`routine <n>
   delete`) ; un champ « Ajouter » qui envoie la ligne à `routine add`.

Les données se rechargent à l'ouverture et sur un Timer de 5 s tant que
la fenêtre est visible. Le panneau (ControlCenterModule) gagne deux
boutons sous le dernier échange : « Journal » (ouvre la fenêtre) et
« Oublier » (undo --quiet), et « Routines : n » dans le repli
Automatismes.

## Tests

tests/run : fixture `tests/fixtures/session.jsonl` (deux échanges, avec
réflexion et outil) sous `JARVIS_CLAUDE_PROJECTS=$SB/projects` ; tests
de `transcript`, `conversations`, `undo` (sauvegarde, troncature, journal,
paire, refus hors idle, refus sans conversation), `is_undo` à la voix ;
routines : parseur (`due` à heure fixe via `--now`), tampon, rattrapage
10 min, silence, `once`, `routine add/on/off/delete`, `status`.

## Lots

A. jarvis-transcript + verbes undo/transcript/conversations + voix.
B. jarvis-routines + tick + verbes routines + fiche + CLAUDE.md.
C. Fenêtre Journal + boutons du panneau (plugin), install.sh inchangé
   (copie déjà Service.qml/ControlCenterModule.qml/components).
