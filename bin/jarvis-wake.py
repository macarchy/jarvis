#!/usr/bin/env python3
"""jarvis-wake — ears that never close.

Streams the internal microphone through openWakeWord and drives the jarvis
state machine. This file is the capture loop and nothing else: the model, the
microphone, the subprocesses. WHAT to do with a frame of audio is decided by
bin/jarvis_wake_fsm.py, which knows nothing of any of that and is therefore
the part a test can drive — see tests/test_wake_fsm.py.

- "Hey Jarvis" (score > threshold) while he is idle or sleeping fires
  `omarchy-jarvis press` — summon, or wake from a dream.
- While he TRANSCRIBES or THINKS the same word aborts instead, at a slightly
  higher threshold: those are the two states where the machine is working on
  your behalf and, until the modal press landed, nothing in the whole system
  could stop it. Never while he SPEAKS: the accent verifier is trained on his
  own Piper voices, so his replies would score as wake words there (barge-in
  stays on the key and the fish).
- While he is LISTENING, the same audio stream does endpointing: once speech
  has been heard, ~1.2 s of silence presses again to stop the recording — so
  a wake-word exchange needs no key at all, and a manual press-to-talk
  auto-stops too. Twenty seconds with no speech at all cancels instead: an
  empty window is an abandoned attempt, not a question.
- While he is in FOLLOWUP (just finished speaking), a speech onset within the
  window presses — the rejoinder needs no wake word — and silence settles him.

Runs from the venv under wake/venv (see bin/jarvis-wake launcher).
"""

import os
import subprocess
import sys
import time

import numpy as np
import openwakeword
from openwakeword.model import Model

BIN_DIR = os.path.dirname(os.path.realpath(__file__))
JARVIS_DIR = os.path.dirname(BIN_DIR)
sys.path.insert(0, BIN_DIR)
import jarvis_wake_fsm as fsm  # noqa: E402 — the path above is what finds it

# The French-accent verifier (wake/train-verifier) and its shim.
sys.path.insert(0, os.path.join(JARVIS_DIR, "wake"))
VERIFIER = os.path.join(JARVIS_DIR, "wake", "verifier-hey-jarvis.joblib")
# JARVIS_RUN for the same reason bin/jarvis has it: a daemon and an FSM that
# do not agree on where the state lives cannot be tested together.
RUN_DIR = os.environ.get("JARVIS_RUN") or os.path.join(
    os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "jarvis")
STATE_FILE = os.path.join(RUN_DIR, "state")
MIC_TARGET = os.environ.get("JARVIS_MIC", "effect_output.j493-mic")

CHUNK = 1280                    # 80 ms at 16 kHz
# With the accent verifier the score IS the verifier's probability
# (positives saturate near 1.0, phonetic twins stay under ~0.75), so the
# threshold sits high. Without it, the base model's English-native scores
# apply and 0.30 barely catches an effortful French attempt.
# Tune with the score trace in $XDG_RUNTIME_DIR/jarvis/wake-score.
HAS_VERIFIER = os.path.exists(VERIFIER)
WAKE_THRESHOLD = float(os.environ.get(
    "JARVIS_WAKE_THRESHOLD", "0.8" if HAS_VERIFIER else "0.30"))


def state():
    try:
        with open(STATE_FILE) as f:
            return f.read().strip() or "idle"
    except OSError:
        return "idle"


def run(args):
    subprocess.Popen(["omarchy-jarvis", *args],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def trace_score(score):
    # Anything voice-like is traced so a real attempt that lands under the
    # threshold is visible and tunable.
    if score <= 0.08:
        return
    try:
        with open(os.path.join(RUN_DIR, "wake-score"), "a") as f:
            f.write(f"{time.strftime('%H:%M:%S')} {score:.3f}\n")
    except OSError:
        pass


def mic_args():
    have = subprocess.run(["pactl", "list", "sources", "short"],
                          capture_output=True, text=True).stdout
    target = ["--target", MIC_TARGET] if MIC_TARGET in have else []
    return ["pw-record", *target, "--rate", "16000", "--channels", "1",
            "--format", "s16", "-"]


def main():
    kwargs = {}
    if HAS_VERIFIER:
        import verifier_shim  # noqa: F401 — the pickle resolves its class here
        kwargs = dict(custom_verifier_models={"hey_jarvis_v0.1": VERIFIER},
                      custom_verifier_threshold=0.005)
    model = Model(wakeword_model_paths=[
        openwakeword.models["hey_jarvis"]["model_path"]], **kwargs)

    st = fsm.new_state(WAKE_THRESHOLD)
    floor = 60.0                # RMS in int16 units, adapts continuously

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
                score = None
                if fsm.wants_score(mode):
                    score = max(model.predict(audio).values())
                    trace_score(score)
                action, floor = fsm.decide(mode, rms, floor, score, now, st)
                if not action:
                    continue
                # The model only ever fired if it was asked, so this is
                # exactly the wake-word triggers and nothing else.
                if score is not None:
                    model.reset()
                run(fsm.command_for(action, mode))
        finally:
            proc.kill()
        time.sleep(1.0)         # pw-record died; let the graph settle


if __name__ == "__main__":
    sys.exit(main())
