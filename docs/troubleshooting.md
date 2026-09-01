# When something is red

`omarchy-jarvis doctor` names every dependency, green or red, with no
guessing and no LLM involved. Its exit code is the number of problems. This
page is one entry per line it can print, in the order it prints them.

Run it first. Whatever it says is fine, is fine.

```sh
omarchy-jarvis doctor          # the whole check
omarchy-jarvis doctor --mic    # plus a real half-second capture
omarchy-jarvis doctor --quiet  # only the red lines
```

---

### ✗ claude (le cerveau)

Claude Code is not installed or not on `PATH`. Install it from
[claude.com/claude-code](https://claude.com/claude-code) and sign in — Jarvis
never handles your credentials, it just runs `claude -p`.

Green but he still says *« Je n'ai pas pu joindre mon cerveau »*? Check
`omarchy-jarvis status | grep brain`. `quota <epoch>` means you hit a usage
limit and he will resume by himself; `down` means the last call failed. The
reason is in `memory/trace/<today>.log`.

### ✗ voxtype (l'oreille)

The transcriber is missing. Install it from [voxtype.io](https://voxtype.io).
It is a separate project with its own configuration; Jarvis only writes a
derived config with the language pinned, and calls it.

Installed but transcribing nothing? The Whisper model is probably absent —
`./bootstrap.sh` puts `ggml-small.bin` in `~/.local/share/voxtype/models/`.

### ✗ pw-record / ✗ pw-play

PipeWire's command-line tools are missing. On Arch they are in `pipewire`
itself; elsewhere look for a `pipewire-tools` or `pipewire-utils` package.
There is no fallback to ALSA or PulseAudio.

### ✗ piper : une synthèse réelle

This check does not test that the file exists — it actually synthesizes a
short phrase, because a voice model truncated by a full disk is present,
executable and silent. Re-run `./bootstrap.sh`; it re-fetches only what is
missing or broken.

Also check you have room: the models are 60 MB each and a partial download is
the classic cause.

### ✗ voix anglaise

`models/en_GB-alan-medium.onnx` is missing. `./bootstrap.sh`.

### ✗ micro (…) présent

Jarvis records from one named node rather than the system default, because the
default has been seen wandering off to a webcam mid-session. The name is
`effect_output.j493-mic` — an Asahi-specific node that will not exist on your
machine.

List yours and pin it:

```sh
pactl list sources short
export JARVIS_MIC=alsa_input.pci-0000_00_1f.3.analog-stereo
```

Set it permanently in the systemd units, or leave `JARVIS_MIC` unset — if the
named node is absent, Jarvis falls back to the system default, which is
usually right.

### ✗ micro : capture réelle *(only with `--mic`)*

The node exists but records silence. Check it is not muted
(`wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0`), that nothing else holds it
exclusively, and that your desktop's portal is not blocking access.

### ✗ daemon wake (hey Jarvis)

The wake daemon is not running. It is optional — the push-to-talk key works
without it — and it starts from your compositor's autostart:

```lua
o.exec_on_start("omarchy-jarvis-wake")   -- ~/.config/hypr/autostart.lua
```

Start it now with `omarchy-jarvis-wake &`. If it exits immediately saying
`already running`, another copy holds the lock; that is the check working.

**He does not hear his name.** The model is trained on native English. Say
*héï djâ-vis*, the English way. A fresh clone has no accent verifier, so the
threshold is `0.30`; the score trace is at
`$XDG_RUNTIME_DIR/jarvis/wake-score`, and `JARVIS_WAKE_THRESHOLD` overrides it.
Train a verifier on your own voice with `wake/train-verifier` and it rises to
`0.8` with far fewer false positives.

### ✗ venv wake + openwakeword

`./bootstrap.sh` builds `wake/venv`. If it failed, the usual cause is that
`onnxruntime` has no wheel for your Python version — build the venv against an
older interpreter:

```sh
rm -rf wake/venv && python3.12 -m venv wake/venv
wake/venv/bin/pip install openwakeword onnxruntime numpy scikit-learn joblib
```

### ✗ planches du poisson / ✗ poisson conforme à l'âme

The sprite sheets are missing, or they no longer match the five appearance
settings in `SOUL.md`. Both are one command:

```sh
omarchy-jarvis look           # regenerate from the soul
omarchy-jarvis look random    # roll a new fish first
```

The sheets live in `~/.local/share/jarvis/sprites/`, deliberately outside the
plugin directory — the shell hot-reloads on any change in there.

### ✗ greffon installé

The mascot plugin is not in `~/.config/omarchy/plugins/`. Run `./install.sh`,
then `omarchy plugin enable macarchy.jarvis`.

This one is expected to be red if you are not running Omarchy and Quickshell.
Nothing else breaks: the fish is the *body* layer, and every call into it is
`|| true`.

### ✗ unités systemd installées et actives

The user units are missing or stopped. `./install.sh` installs and enables
them. To check by hand:

```sh
systemctl --user is-active jarvis-tick.timer jarvis-inbox.path
systemctl --user list-timers jarvis-tick.timer
```

`jarvis-tick.timer` is the pulse — the watchdog, the rounds, the dreams, the
conversation rotation and the inbox retries all hang off it. Without it, those
stop the moment anything wedges. `jarvis-inbox.path` watches `~/Jarvis/input`.

### ✗ omarchy-jarvis pointe sur ce dépôt

`~/.local/bin/omarchy-jarvis` resolves somewhere else — usually a second
checkout. Whichever one you meant, run its `./install.sh`.

### ✗ boîte … / ✗ symlink memory

`~/Jarvis` is missing or its `memory` symlink does not point at this
checkout's `memory/`. Any Jarvis command recreates the box; the symlink is
`ln -s <checkout>/memory ~/Jarvis/memory`.

### ✗ settings.json valide

`.claude/settings.json` is not valid JSON, which means the brain is running
with **no** tool allowlist. Fix it before speaking to him again:

```sh
python3 -m json.tool .claude/settings.json
```

### ✗ prompts (ronde, rêve, digestion)

One of `memory/HEARTBEAT_PROMPT.md`, `DREAM_PROMPT.md` or `DIGEST_PROMPT.md`
is missing. They are tracked; `git checkout memory/` restores them.

### ✗ connaissance à jour (omarchy)

`memory/knowledge/` was generated against an older Omarchy. It is rebuilt by
introspection, no LLM involved:

```sh
omarchy-jarvis index
```

The pulse does this automatically after an Omarchy update.

---

## Things doctor cannot see

**He is stuck.** `omarchy-jarvis state` says `thinking` and nothing moves.
Press the key — while transcribing or thinking it cancels. Or:

```sh
omarchy-jarvis cancel
omarchy-jarvis watchdog    # what the pulse runs every 60 s
```

`doctor` reports a state older than ten minutes as a problem, with the command
to clear it.

**He answers an empty room.** Whisper hallucinates on silence — *« Sous-titres
réalisés par la communauté d'Amara.org »* is the classic. Raise
`JARVIS_WAKE_THRESHOLD`, or train the accent verifier so the wake word stops
firing on ambient noise.

**He speaks the wrong language.** The reply's language is chosen per reply from
`SOUL.md`'s `langue` setting (`fr`, `en`, or `auto`). Pin it rather than
leaving it on `auto` — detection is unreliable on short phrases.

**Nothing at all happens on the key.** Check the binding reached the
compositor: `hyprctl binds | grep -A2 jarvis`. A binding edited in
`~/.config/hypr/bindings.lua` needs the config reloaded before it exists.

## Still stuck

Open an issue with the output of `omarchy-jarvis doctor`. If the problem is
behavioural rather than structural, `memory/trace/<date>.log` is the black
box — **read it before pasting it**, it is a log of your machine.
