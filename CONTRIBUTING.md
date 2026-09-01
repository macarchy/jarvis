# Contributing

Thanks for looking. Jarvis is one person's assistant made public because the
mechanism is worth reading — so the bar here is less "does it work" and more
"will this still make sense in a year".

## Before you start

Run the suite. It is the fastest way to learn what the machine promises:

```sh
./tests/run        # the whole pipeline, offline, in about two minutes
```

Then open [`bin/jarvis-fsm.sh`](bin/jarvis-fsm.sh) and read the prose above the
code. Eight states, nine events, 38 legal pairs out of 72. Almost every change
worth making touches that table, and the table is the documentation of record.

## The rules that keep it honest

**Never run the real pipeline to test a change.** No `omarchy-jarvis press`,
`ask`, `say`, `dream` or `heartbeat` against real state — it takes the
microphone, speaks out loud, and spends someone's Claude quota. Drive
everything through `tests/run`, or through a sandbox with `JARVIS_RUN`,
`JARVIS_STATE`, `JARVIS_MEMORY` and `JARVIS_BOX` pointed at a temp directory.

**The state file is a public contract.** `$XDG_RUNTIME_DIR/jarvis/state` is
exactly one lowercase word, forever. The wake daemon reads it, and so does an
out-of-repo Touch Bar daemon. Richer information goes in `state.rec` beside it.

**The transition table cannot drift.** `tests/fixtures/transitions.txt` is the
grid frozen; the suite diffs it against what the machine actually prints. If
you change the table, regenerate the fixture *and say why in the commit*.

**His memory is not tracked, and must not become tracked.** `memory/journal/`,
`LEARNED.md`, `CONVERSATION.md`, `FAILURES.md`, `ABORTS.md` and
`SUGGESTIONS.md` are what one Jarvis lived through with one person. Only their
headers are in the repository, under `memory/scaffold/`, and `memory_init`
restores them on the first command. The three `*_PROMPT.md` and
`memory/skills/` *are* tracked — those are the project.

**A change to the state machine that no test covers is not finished.** That
surface had zero coverage once, and it cost ten confirmed bugs.

## The house style

- **Bash** for the state machine. Python only for stream parsing, audio and
  sprites. QML for the mascot. No new runtime dependencies without a good
  reason — this runs on a laptop, on battery.
- **Comments are prose, in English**, explaining *why*, in a paragraph above a
  function or a section. Not a line-by-line narration of what the code plainly
  says. This codebase reads like an essay; keep it that way.
- **Everything the user hears or reads is French** — notifications, journal
  lines, the voice, `FAILURES.md`, `ABORTS.md`. Code, comments and identifiers
  are English. The seam is deliberate: one language for the machine, one for
  the person.
- Match the surrounding file. If your diff reads like a different author wrote
  it, it is not done.

## Things that are easy to get wrong

- **`set -uo pipefail` without `-e`.** A failing command continues. If your new
  code path can fail, say what happens when it does.
- **Killing a pid is not killing a stage.** Every external stage runs in its own
  process group (`group_run`), because killing the group is what reaches the
  subprocesses `claude` spawns for its own tools.
- **A stage must check `mine`.** An invocation whose epoch has moved on has been
  superseded and must go quiet rather than finish work nobody wants.
- **`find -newermt` and fractional `-mmin` do not work here.** `/usr/bin/find`
  is `bfs` on the reference machine. Compare `stat -c %Y` in bash instead.
- **Do not write into `~/.config/omarchy/plugins/*` file by file.** The shell
  hot-reloads on any change there and has a use-after-free. `install.sh` stages
  into a hidden directory and swaps with renames; keep it that way.

## Reporting a bug

`omarchy-jarvis doctor` output is worth more than a description. If the problem
is behavioural, `memory/trace/<date>.log` is the black box — every command
Jarvis ran and what it returned. **Read it before you paste it:** it is a log
of your machine, and it can contain anything you asked him about.

## What a good pull request looks like

One coherent change. The tests it needs. A commit message that says what
changed and why, in the tone of the file it touched. If you found the brief or
the docs wrong, say so in the PR rather than silently working around it — that
is the most useful thing a second pair of eyes does here.
