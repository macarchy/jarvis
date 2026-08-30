#!/usr/bin/env python3
"""jarvis-wake — ears that never close.

Streams the internal microphone through openWakeWord and drives the
jarvis state machine:

- "Hey Jarvis" (score > threshold) while he is idle, speaking or sleeping
  fires `omarchy-jarvis press` — summon, barge-in, or wake from a dream.
- While he is LISTENING, the same audio stream does endpointing: once
  speech has been heard, ~1.2 s of silence (or a 20 s cap) presses again
  to stop the recording — so a wake-word exchange needs no key at all,
  and a manual press-to-talk auto-stops too.

Runs from the venv under wake/venv (see bin/jarvis-wake launcher).
"""

import os
import subprocess
import sys
import time

import numpy as np
import openwakeword
from openwakeword.model import Model

JARVIS_DIR = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
RUN_DIR = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "jarvis")
STATE_FILE = os.path.join(RUN_DIR, "state")
MIC_TARGET = os.environ.get("JARVIS_MIC", "effect_output.j493-mic")

CHUNK = 1280                    # 80 ms at 16 kHz
WAKE_THRESHOLD = 0.5
WAKE_COOLDOWN = 3.0             # s between wake triggers
SILENCE_HOLD = 1.2              # s of quiet that ends an utterance
LISTEN_CAP = 20.0               # s hard cap on a listening window
SPEECH_FACTOR = 5.0             # speech = noise floor × this
QUIET_FACTOR = 2.5              # silence = below noise floor × this


def state():
    try:
        with open(STATE_FILE) as f:
            return f.read().strip() or "idle"
    except OSError:
        return "idle"


def press():
    subprocess.Popen(["omarchy-jarvis", "press"],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def mic_args():
    have = subprocess.run(["pactl", "list", "sources", "short"],
                          capture_output=True, text=True).stdout
    target = ["--target", MIC_TARGET] if MIC_TARGET in have else []
    return ["pw-record", *target, "--rate", "16000", "--channels", "1",
            "--format", "s16", "-"]


def main():
    model = Model(wakeword_model_paths=[
        openwakeword.models["hey_jarvis"]["model_path"]])

    noise_floor = 60.0          # RMS in int16 units, adapts continuously
    last_wake = 0.0
    listen_since = None
    speech_heard = False
    quiet_since = None

    while True:
        proc = subprocess.Popen(mic_args(), stdout=subprocess.PIPE)
        try:
            while True:
                raw = proc.stdout.read(CHUNK * 2)
                if not raw or len(raw) < CHUNK * 2:
                    break
                audio = np.frombuffer(raw, dtype=np.int16)
                rms = float(np.sqrt(np.mean(audio.astype(np.float32) ** 2)))
                now = time.monotonic()
                mode = state()

                if mode == "listening":
                    if listen_since is None:
                        listen_since = now
                        speech_heard = False
                        quiet_since = None
                    if rms > noise_floor * SPEECH_FACTOR:
                        speech_heard = True
                        quiet_since = None
                    elif speech_heard and rms < noise_floor * QUIET_FACTOR:
                        quiet_since = quiet_since or now
                        if now - quiet_since >= SILENCE_HOLD:
                            press()
                            listen_since = None
                    if listen_since and now - listen_since >= LISTEN_CAP:
                        press()
                        listen_since = None
                    continue

                # Out of listening: track the room's noise floor slowly and
                # watch for the wake word.
                listen_since = None
                noise_floor = 0.995 * noise_floor + 0.005 * max(rms, 1.0)

                if mode in ("idle", "speaking", "sleeping"):
                    score = max(model.predict(audio).values())
                    if score > WAKE_THRESHOLD and now - last_wake > WAKE_COOLDOWN:
                        last_wake = now
                        model.reset()
                        press()
        finally:
            proc.kill()
        time.sleep(1.0)         # pw-record died; let the graph settle


if __name__ == "__main__":
    sys.exit(main())
