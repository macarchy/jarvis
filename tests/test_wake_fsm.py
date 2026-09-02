#!/usr/bin/env python3
"""Les oreilles, sans micro : la table de décision de bin/jarvis_wake_fsm.py.

Toute la logique d'écoute — la fin de phrase après 1,2 s de silence, le
plafond de vingt secondes, la fenêtre de relance, le mot de réveil selon
l'état — pilotait cette machine depuis des semaines sans qu'aucun test ne
l'ait jamais exécutée : il fallait un micro, un modèle entraîné et du temps
réel pour la reproduire. Ici il ne faut que des nombres.

Chaque cas joue une suite de trames de 80 ms et compare les actions obtenues
à celles attendues. Sortie : le nombre de cas ratés.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(
    os.path.realpath(__file__))), "bin"))

import jarvis_wake_fsm as fsm  # noqa: E402

FRAME = 0.08                    # 80 ms, one CHUNK at 16 kHz
FLOOR = 60.0                    # the noise floor the daemon starts from
SPEECH = FLOOR * fsm.SPEECH_FACTOR + 1      # loud enough to be a voice
QUIET = FLOOR * fsm.QUIET_FACTOR - 1        # quiet enough to be a room
THRESHOLD = 0.8

fails = []


class Ears:
    """One daemon, one clock. `frame` is one 80 ms slice of audio."""

    def __init__(self, threshold=THRESHOLD, floor=FLOOR):
        self.st = fsm.new_state(threshold)
        self.floor = floor
        self.now = 1000.0       # a monotonic clock never starts at zero

    def frame(self, mode, rms=QUIET, score=None, dt=FRAME):
        self.now += dt
        if score is not None and not fsm.wants_score(mode):
            raise AssertionError(f"score calculé pour rien en « {mode} »")
        action, self.floor = fsm.decide(
            mode, rms, self.floor, score, self.now, self.st)
        return action

    def seconds(self, mode, secs, rms=QUIET, score=None):
        """The same frame, for that long. Returns every action it produced."""
        out = []
        for _ in range(int(secs / FRAME)):
            a = self.frame(mode, rms=rms, score=score)
            if a:
                out.append(a)
        return out


def check(name, got, want):
    if got != want:
        fails.append(f"✗ {name} : {got!r} au lieu de {want!r}")


# --- la fin de phrase ------------------------------------------------------

ears = Ears()
check("une trame de parole seule n'arrête rien",
      ears.seconds("listening", 0.5, rms=SPEECH), [])
# 1,2 s de silence après la parole : un seul press, et pas avant l'heure.
check("le silence n'arrête rien avant 1,2 s",
      ears.seconds("listening", 1.0, rms=QUIET), [])
check("puis la phrase est close, une fois",
      ears.seconds("listening", 0.5, rms=QUIET), ["press"])

# Le silence AVANT toute parole n'est pas une fin de phrase : c'est quelqu'un
# qui n'a pas encore parlé. C'est le cas qui fermait la fenêtre aussitôt.
ears = Ears()
check("le silence initial ne ferme pas la fenêtre",
      ears.seconds("listening", 5.0, rms=QUIET), [])

# --- le plafond de vingt secondes ------------------------------------------

ears = Ears()
ears.seconds("listening", 1.0, rms=SPEECH)
check("parole puis silence : la fin de phrase l'emporte sur le plafond",
      ears.seconds("listening", 2.0, rms=QUIET), ["press"])

# Vingt secondes de parole ininterrompue : le plafond tranche, et c'est bien
# une question qu'il faut transcrire.
ears = Ears()
check("plafond atteint avec de la parole → press",
      ears.seconds("listening", 21.0, rms=SPEECH), ["press"])

# Vingt secondes de pièce vide : ce n'est pas une transcription qui a raté,
# c'est une tentative abandonnée. La transcrire donnait « Sous-titres
# réalisés par la communauté d'Amara.org », lu à voix haute et journalisé.
ears = Ears()
check("plafond atteint sans un mot → annulation",
      ears.seconds("listening", 21.0, rms=QUIET), ["cancel"])
check("et l'annulation d'une pièce vide ne parle pas",
      fsm.command_for("cancel", "listening"), ["cancel", "--from", "silence"])

# --- la fenêtre de relance -------------------------------------------------

ears = Ears()
check("rien ne se ferme avant six secondes",
      ears.seconds("followup", 5.0), [])
check("puis la fenêtre se referme, une fois",
      ears.seconds("followup", 2.0), ["settle"])

# Un press par reprise, pas un par trame. L'état met une fourche et un
# démarrage de shell à changer — une trame entière — et chaque trame de la
# phrase prononcée relançait un press dans cet intervalle.
ears = Ears()
check("une reprise de parole rouvre l'oreille, une seule fois",
      ears.seconds("followup", 0.4, rms=SPEECH), ["press"])
check("et la fermeture ne se répète pas non plus",
      Ears().seconds("followup", 20.0), ["settle"])

# Mais un press peut ne rien changer : la machine refuse celui qui tombe
# dans son propre temps mort (250 ms après une transition). La fenêtre qui
# avait tiré puis cessé de regarder restait ouverte — ni relance, ni
# fermeture — jusqu'au chien de garde. L'état toujours à « followup » une
# demi-seconde plus tard, c'est un press perdu : on le retire.
ears = Ears()
check("un press perdu est retenté une demi-seconde plus tard",
      ears.seconds("followup", 1.0, rms=SPEECH), ["press", "press"])
# Et une fenêtre dont le press s'est perdu se referme quand même à six
# secondes, comme n'importe quelle fenêtre inutilisée.
ears = Ears()
check("le press part", ears.frame("followup", rms=SPEECH), "press")
check("la fenêtre au press perdu se referme quand même",
      ears.seconds("followup", 6.5), ["settle"])

# --- le mot de réveil, état par état ---------------------------------------

WAKE = THRESHOLD + 0.15         # au-dessus du seuil ET de la marge d'abandon
for mode, want in [("idle", "press"), ("sleeping", "press"),
                   ("transcribing", "cancel"), ("thinking", "cancel")]:
    ears = Ears()
    check(f"« hey jarvis » en {mode}", ears.frame(mode, score=WAKE), want)

# Les quatre autres états n'écoutent même pas : pendant qu'il parle, le
# vérificateur d'accent — entraîné sur ses propres voix Piper — prend ses
# répliques pour le mot de réveil (0,84 relevé dans la trace).
for mode in ("speaking", "listening", "followup", "cancelling"):
    check(f"aucun score n'est calculé en {mode}", fsm.wants_score(mode), False)

# La marge : en réflexion, un faux positif détruit du travail au lieu de
# n'enregistrer que du bruit, donc le seuil monte de 0,1.
ears = Ears()
check("un score juste au-dessus du seuil n'annule pas",
      ears.frame("thinking", score=THRESHOLD + 0.05), "")
ears = Ears()
check("le même score réveille depuis idle",
      ears.frame("idle", score=THRESHOLD + 0.05), "press")

# Le temps de garde : deux réveils à une seconde d'intervalle sont un seul.
ears = Ears()
check("premier réveil", ears.frame("idle", score=WAKE), "press")
check("le second est avalé", ears.seconds("idle", 1.0, score=WAKE), [])
check("le troisième, trois secondes plus tard, passe",
      ears.seconds("idle", 3.0, score=WAKE), ["press"])

# --- le bruit de fond ------------------------------------------------------

# Le fond ne bouge que hors des deux fenêtres : une question criée dans le
# micro ne doit pas relever le seuil de parole qui la mesure.
ears = Ears()
ears.seconds("listening", 2.0, rms=SPEECH)
check("le fond ne bouge pas pendant l'écoute", round(ears.floor, 6), FLOOR)
ears = Ears()
ears.seconds("idle", 2.0, rms=SPEECH, score=0.0)
check("le fond monte dans une pièce bruyante", ears.floor > FLOOR, True)

# --- l'abandon depuis une demande en cours ---------------------------------

check("une annulation demandée à la voix répond à voix haute",
      fsm.command_for("cancel", "thinking"),
      ["cancel", "--say", "--from", "voix"])
check("un press reste un press", fsm.command_for("press", "idle"), ["press"])
check("un settle reste un settle",
      fsm.command_for("settle", "followup"), ["settle"])

for line in fails:
    print(line)
print(f"{len(fails)} cas raté(s) sur les oreilles")
sys.exit(1 if fails else 0)
