"""jarvis_wake_fsm — what the ears decide, with no ears attached.

bin/jarvis-wake.py owns the microphone, the wake model and the subprocesses.
Everything it DECIDES lives here, as one function over numbers. The split is
the whole point: the endpointing, the twenty-second cap, the follow-up window
and the wake word have driven this machine for weeks and had never once been
run by a test — reproducing any of them needed a microphone, a trained model
and real time, which in practice meant they were verified by talking to a
laptop and hoping.

decide() is given what a frame of audio amounts to — its loudness, the room's
noise floor, the wake model's score if one was computed — plus the state word
the pipeline publishes and a monotonic clock, and answers with one of:

    ""        nothing to do
    "press"   advance the machine: open the ear, or close it
    "settle"  close an unused follow-up window
    "cancel"  stop what he is doing

together with the noise floor to carry into the next frame. Its own memory —
when the current window opened, whether anyone has spoken in it, when the
quiet started, when the last wake word fired — lives in the dict `st`, which
the caller makes once with new_state() and otherwise never touches. Nothing
here opens a file, spawns a process or imports anything.
"""

SILENCE_HOLD = 1.2              # s of quiet that ends an utterance
LISTEN_CAP = 20.0               # s hard cap on a listening window
FOLLOWUP_WINDOW = 6.0           # s to start a rejoinder after a reply
SPEECH_FACTOR = 5.0             # speech = noise floor × this
QUIET_FACTOR = 2.5              # silence = below noise floor × this
WAKE_COOLDOWN = 3.0             # s between wake triggers
FLOOR_DECAY = 0.995             # how slowly the room's noise floor moves

# Where a wake word summons him.
WAKE_STATES = ("idle", "sleeping")
# And where it aborts instead. The objection in the daemon's docstring — the
# accent verifier is trained on the very Piper voices Jarvis speaks with, so
# his own replies score as wake words — is about `speaking`, and only about
# it. While he transcribes and thinks nothing is playing and the only voice
# in the room is a human one. The threshold is still raised there, by
# ABORT_MARGIN: a false positive now destroys work instead of merely
# recording a few seconds of it.
ABORT_STATES = ("transcribing", "thinking")
ABORT_MARGIN = 0.1


def new_state(threshold):
    """The daemon's memory across frames. `threshold` is the wake score to
    beat, which depends on whether the accent verifier is installed — that is
    the caller's business, not this module's."""
    return {
        "threshold": float(threshold),
        "listen_since": None,
        "speech_heard": False,
        "quiet_since": None,
        "followup_since": None,
        "followup_done": False,
        "last_wake": 0.0,
    }


def wants_score(mode):
    """True when the caller has to run the wake model on this frame. Anywhere
    else the score is not merely unused, it is not worth computing."""
    return mode in WAKE_STATES or mode in ABORT_STATES


def decide(mode, rms, floor, score, now, st):
    """One frame. Returns (action, floor)."""
    if mode == "listening":
        st["followup_since"] = None
        st["followup_done"] = False
        if st["listen_since"] is None:
            st["listen_since"] = now
            st["speech_heard"] = False
            st["quiet_since"] = None
        if rms > floor * SPEECH_FACTOR:
            st["speech_heard"] = True
            st["quiet_since"] = None
        elif st["speech_heard"] and rms < floor * QUIET_FACTOR:
            st["quiet_since"] = st["quiet_since"] or now
            if now - st["quiet_since"] >= SILENCE_HOLD:
                # The end of an utterance: he stops recording by himself, so
                # a wake-word exchange needs no key at all.
                st["listen_since"] = None
                return "press", floor
        if now - st["listen_since"] >= LISTEN_CAP:
            heard = st["speech_heard"]
            st["listen_since"] = None
            # Twenty seconds and not one word: that is an abandoned attempt,
            # not a failed transcription. Pressing here handed whisper twenty
            # seconds of room tone, and whisper answers room tone with
            # « Sous-titres réalisés par la communauté d'Amara.org » — which
            # then reached the brain, the speakers and the journal as a real
            # question, six times on 2026-09-01 alone.
            return ("press" if heard else "cancel"), floor
        return "", floor

    if mode == "followup":
        # The reply just ended: a few seconds where speaking again needs no
        # wake word. A speech onset presses (the endpointing above takes
        # over); silence settles him.
        #
        # A window is consumed once, and `followup_done` is what says so. The
        # state word takes a fork and a shell start-up to change — eighty
        # milliseconds, a whole frame — and without the flag every frame of
        # the sentence being spoken fired another press into that gap. The
        # dead time on `press` swallowed them, so it never showed; it was
        # still a handful of processes per rejoinder, and before that dead
        # time existed it was a second press against an 80 ms recording.
        if st["followup_done"]:
            return "", floor
        if st["followup_since"] is None:
            st["followup_since"] = now
        if rms > floor * SPEECH_FACTOR:
            st["followup_since"] = None
            st["followup_done"] = True
            return "press", floor
        if now - st["followup_since"] >= FOLLOWUP_WINDOW:
            st["followup_since"] = None
            st["followup_done"] = True
            return "settle", floor
        return "", floor

    # Out of the two windows: track the room's noise floor slowly, and watch
    # for the wake word wherever it means something.
    st["listen_since"] = None
    st["followup_since"] = None
    st["followup_done"] = False
    floor = FLOOR_DECAY * floor + (1.0 - FLOOR_DECAY) * max(rms, 1.0)
    if score is None:
        return "", floor
    if mode in ABORT_STATES:
        if score > st["threshold"] + ABORT_MARGIN and now - st["last_wake"] > WAKE_COOLDOWN:
            st["last_wake"] = now
            return "cancel", floor
        return "", floor
    if mode in WAKE_STATES:
        if score > st["threshold"] and now - st["last_wake"] > WAKE_COOLDOWN:
            st["last_wake"] = now
            return "press", floor
    return "", floor


def command_for(action, mode):
    """The action as `omarchy-jarvis` wants it. An abort asked for out loud,
    while the user is watching a request he can see, answers out loud; a
    listening window that timed out on an empty room does not — there is
    nobody in it to tell."""
    if action != "cancel":
        return [action]
    if mode == "listening":
        return ["cancel", "--from", "silence"]
    return ["cancel", "--say", "--from", "voix"]
