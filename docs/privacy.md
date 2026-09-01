# What Jarvis knows, keeps, and sends

Jarvis holds a microphone open, reads your screen when asked, and hands your
words to a company's servers. That deserves a plain accounting rather than a
reassuring paragraph. Everything below is checkable in the source; the file
and line are named so you do not have to take this document's word for it.

## The short version

| | Where it goes | Kept |
|---|---|---|
| Your audio | nowhere — transcribed on your CPU | overwritten by the next utterance |
| Your transcript | **Anthropic**, as the prompt | in `memory/journal/`, on your disk |
| His reply | your speakers | same |
| A screenshot | **Anthropic**, only when you ask in that exchange | `~/.cache/jarvis/screen.png`, overwritten |
| Your clipboard | **Anthropic**, only when you ask | not kept separately |
| Every command he runs | nowhere | `memory/trace/<date>.log`, on your disk |

## Audio never leaves the machine

`pw-record` writes one WAV to `$XDG_RUNTIME_DIR/jarvis/utterance.wav`.
`voxtype` — Whisper, running locally on your CPU — turns it into text. The next
recording overwrites the file, and `$XDG_RUNTIME_DIR` is cleared when you log
out. No audio is uploaded, at any point, by any part of this.

The synthesized reply is the same: Piper runs locally, and the WAV it produces
lives beside the recording until the next one replaces it.

## The transcript goes to Anthropic

The brain is [Claude Code](https://claude.com/claude-code), invoked as
`claude -p` once per exchange (`bin/jarvis:627`). What it receives:

- what you said, as text;
- `CLAUDE.md` and `SOUL.md` — his instructions and personality;
- `memory/LEARNED.md` — the lessons his dreams distilled;
- `memory/CONVERSATION.md` — a summary of the last closed conversation;
- the running conversation, resumed by session id across exchanges;
- and whatever he reads *while* answering you, which is the part below.

Anthropic's handling of that is theirs to state, not this project's. If that is
not acceptable for something you are about to say, the answer is to not say it
to Jarvis.

## What he can read, and when

His tools are an explicit allowlist in `.claude/settings.json` — if a command
is not in it, the call is refused. The ones that touch your data:

- **`grim`** — a screenshot, to `~/.cache/jarvis/screen.png`, which he then
  reads. Only on an explicit request in the current exchange (*« résume cette
  page »*), never on his own initiative, and never during an autonomous round
  or a dream. `CLAUDE.md` states that rule; the trace records every use.
- **`wl-paste`** — your clipboard, on the same terms.
- **`hyprctl activewindow`** — the focused window's class and title.
- **`sqlite3` on atuin's history** — your last shell command, its exit code and
  duration.
- **`WebSearch`** — for questions whose answer is not on this machine. Your
  query goes out; that is what a search is.

Anything he reads this way becomes part of the prompt for that turn, and
therefore goes to Anthropic with it.

## Two things that run unattended

**Background missions.** `omarchy-jarvis dispatch` starts a detached
`claude -p` with `--permission-mode acceptEdits` in a directory you name
(`bin/jarvis:1039`). That session **edits files without asking**. It is how
*« corrige le bug de scroll dans mon projet »* works, and it is the most
powerful thing in here. It is triggered by your speech, and the whole run is
logged to `~/.local/state/jarvis/missions/`.

**The inbox.** A file dropped in `~/Jarvis/input` is read by a session with no
Bash, no Edit and no Task — a document you were given is *quoted data*, never an
instruction to follow. `CLAUDE.md` says so explicitly, because a document that
asks to be obeyed is a real attack and the confinement is the real defence.
A lone URL in a `.url` file additionally gets `WebFetch`, and fetching a page
tells that server you fetched it.

## The black box

`memory/trace/<date>.log` records every command Jarvis ran and what came back.
It is how he answers *« pourquoi as-tu fait ça ? »*, and how his dreams find the
root cause behind a failure. It is also, unavoidably, a plain-text log of your
day: the theme you set, the file you asked about, the error you pasted.

It stays on your disk and is never sent anywhere on its own — but it is quoted
back into his context when he is asked to explain himself, and it is the file
to scrub before pasting anything into a bug report.

None of these are tracked by git. The repository carries only their headers,
in `memory/scaffold/`, and they are restored empty on a fresh clone — so
nothing you can say to Jarvis ends up in a commit by accident.

The neighbours: `memory/journal/` (one line per exchange), `memory/FAILURES.md`
(what he could not do), `memory/ABORTS.md` (what you interrupted),
`~/.local/state/jarvis/jarvis.log` (the developer log).

## The microphone, when you are not talking

The wake daemon (`bin/jarvis-wake.py`) holds the microphone open for its whole
life, in 80 ms frames, and scores each against a small local model. Nothing is
written and nothing is sent until it fires. It is optional at install
(`./bootstrap.sh --skip-wake`), and you can stop it at any time:

```sh
pkill -f jarvis-wake.py && omarchy-jarvis settle
```

The push-to-talk key keeps working without it. `omarchy-jarvis doctor` tells
you honestly whether it is running.

## Turning down his autonomy

All of it is in [`SOUL.md`](../SOUL.md), and it takes effect on the next
conversation:

```
rondes: non        no hourly inspection of the machine
reves: non         no memory consolidation while idle
silence: 23-7      hours in which he does nothing unbidden
```

To stop the autonomous pulse entirely:

```sh
systemctl --user disable --now jarvis-tick.timer jarvis-inbox.path
```

He then does nothing at all until you press the key.

## Deleting what he remembers

```sh
omarchy-jarvis reset                       # forget the current conversation
rm -rf memory/trace memory/journal         # forget what he did
: > memory/LEARNED.md                      # forget what he learned about you
rm -rf ~/.local/state/jarvis               # forget his own health and timers
```

Nothing here is synced anywhere. Deleting the files is the whole procedure.
