# Jarvis

A bilingual (français / English) voice assistant that lives on one laptop,
with Claude as its brain, the shell as its hands, and a pixel-art Babel fish
as its face.

> **[macarchy.github.io/jarvis](https://macarchy.github.io/jarvis)** — the documentation site, with the
> state machine you can drive.
>
> *Français : [README.fr.md](README.fr.md)*

```
SUPER + ALT + J          press to speak, press again to answer
« Hey Jarvis »           the same, without touching the keyboard
SUPER + ALT + ESCAPE     stop whatever is in flight
```

Say *« mets le thème clair »* and the theme changes. Ask *« pourquoi ma
dernière commande a échoué ? »* and he reads your shell history and tells
you. Say *« corrige le bug de scroll dans mon projet web »* and he dispatches
a background coding session and reports back when it lands.

He answers in the language you spoke. He remembers yesterday. When he cannot
do something he writes down why, and later — while idle — he reads those
notes back and distils them into lessons he keeps.

---

## Will this run on your machine?

Honestly: **partly**, unless your machine looks a lot like mine. Jarvis is
three layers, and they fail independently, so it is worth knowing which one
you are getting.

| Layer | What it gives you | What it needs |
|---|---|---|
| **The voice loop** | record → transcribe → think → speak, the whole conversation | Linux, PipeWire, [voxtype](https://voxtype.io), [Claude Code](https://claude.com/claude-code), Python 3 — **portable** |
| **The hands** | changing your theme, brightness, network, windows, launching apps | [Omarchy](https://omarchy.org) and Hyprland — its CLI *is* his hands |
| **The body** | the fish in the corner, the speech bubble, the typed prompt bar | [Quickshell](https://quickshell.org) via `omarchy-shell` |

Layer one runs anywhere with a microphone. Layers two and three are written
against a specific desktop and will not pretend otherwise: every call into
them is `|| true`, so on a plain Linux box Jarvis still listens, thinks and
speaks — he just has nothing to touch and no face to make.

The reference machine is an **M2 MacBook Pro running Asahi Linux** under
[macarchy](https://github.com/macarchy) (Omarchy plus a macOS-shaped layer).
`bootstrap.sh` fetches an `arm64` or `amd64` Piper build depending on where
you run it.

You also need a Claude account: the brain is `claude -p`, invoked once per
exchange. Nothing else in the pipeline leaves the machine.

## Install

```sh
git clone https://github.com/macarchy/jarvis.git ~/Work/jarvis
cd ~/Work/jarvis
./bootstrap.sh      # Piper, its voices, the Whisper model, the wake venv
./install.sh        # the CLI symlink, the mascot plugin, the user units
omarchy-jarvis doctor
```

`bootstrap.sh` downloads ~300 MB that the repository deliberately does not
carry (see [THIRD_PARTY.md](THIRD_PARTY.md)); it is resumable and running it
twice fetches nothing. `install.sh` is idempotent too — re-running it is the
supported way to update after a `git pull`.

`doctor` is the answer to *"is it working?"*: every dependency, green or red,
no guessing. Whatever it says is red, [docs/troubleshooting.md](docs/troubleshooting.md)
explains.

Install `claude` and `voxtype` yourself — they have accounts and configuration
of their own and are not Jarvis's to manage.

## What leaves your machine

This matters more than the feature list, so it is here and not in an appendix.
The long version is [docs/privacy.md](docs/privacy.md).

- **Your speech is transcribed locally.** Whisper runs on your CPU. Audio
  never leaves the machine and the recording is overwritten by the next one.
- **Your transcript goes to Anthropic**, because the brain is Claude. So does
  anything Claude reads while answering you — and that can include a
  screenshot or your clipboard, but **only when you ask for it in that
  exchange**, never on his own initiative, and every use is logged.
- **The wake daemon holds the microphone open** whenever it runs. It is
  optional (`--skip-wake`), it matches audio locally against a small model,
  and it records nothing until it fires.
- **Everything he does is written down** in `memory/trace/` — every command,
  every result. That file is how he answers *"why did you do that?"*. It is
  also a plain-text log of your day on your own disk.

You can turn off his autonomy entirely by editing `SOUL.md`: `rondes: non`
stops the hourly inspection, `reves: non` stops the memory consolidation,
`silence: 23-7` gives him hours where he does nothing unbidden.

## How it works

One utterance, five stages, each with a handle on disk so it can be stopped:

```
press ─▶ pw-record ─▶ voxtype (whisper) ─▶ claude -p ─▶ piper ─▶ pw-play
          record          stt                brain       voice    play
```

Underneath is an explicit state machine — eight states, nine events, and only
38 of the 72 pairs are legal. It lives in
[`bin/jarvis-fsm.sh`](bin/jarvis-fsm.sh), written out in prose above the code,
and it is frozen into `tests/fixtures/transitions.txt` so it cannot drift from
its own documentation without turning a test red.

**[The machine, drivable](https://macarchy.github.io/jarvis/machine.html)** —
press the events, watch the fish change, and watch the illegal pairs be
refused with the reason. Thirty seconds there beats reading this section.

The part worth stealing if you build something similar: the state file records
*what* the machine is doing, and a record beside it records *which attempt* is
doing it. Every stage remembers the epoch it entered on and goes quiet if it
has moved. That, plus running each external stage in its own process group, is
what makes cancelling real — killing the group is what reaches the
subprocesses `claude` spawned for its own tools, which a bare pid never does.

## Making him yours

[`SOUL.md`](SOUL.md) is who he is — tone, humour, whether he uses *tu* or
*monsieur*, his language, **which of the three French voices speaks**, his
quiet hours, and the five pieces his fish is assembled from. Edit it freely; it takes effect on the next conversation.

[`CLAUDE.md`](CLAUDE.md) is what he can do — the commands that are his hands,
written as a prompt. Adding a capability usually means one paragraph there and
one line in `.claude/settings.json`.

`« Hey Jarvis »` is trained on native English. Say it the English way
(*héï djâ-vis*); a natural French accent slides under the model. A fresh
clone has no accent verifier, so the threshold defaults to `0.30` — train your
own with `wake/train-verifier` and it rises to `0.8`.

## Development

```sh
./tests/run        # the whole pipeline, fully offline
```

The suite stubs `claude`, `piper`, `voxtype`, `pw-record`, `pw-play` and
`omarchy-shell`, and redirects state and memory into a sandbox. It takes no
microphone, makes no sound, spends no tokens and never touches your real
memory. If it does any of those, that is a bug.

[CONTRIBUTING.md](CONTRIBUTING.md) has the house style and the rules that keep
the machine honest.

## License

MIT — see [LICENSE](LICENSE). The downloaded pieces have licenses of their
own; [THIRD_PARTY.md](THIRD_PARTY.md) lists them.
