"""Le niveau de l'oreille, pour la Touch Bar.

jarvis-wake.py lit le micro par trames de 80 ms ; pendant que Jarvis écoute,
le RMS de chaque trame devient un niveau 0–1 publié sur la prise de
macarchy-touchbar, dix fois par seconde au plus, et le vumètre de la barre bouge
avec la voix. Pas de daemon, pas de prise, une réponse lente : rien, en
silence — c'est de la décoration, et une réponse retardée lui coûte plus
qu'elle ne vaut.
"""
import math
import os
import socket
import time

FULL_DB = 30.0      # autant au-dessus du plancher de bruit : vumètre plein
RATE_HZ = 10.0


def level_of(rms, floor):
    """0 au plancher de bruit, 1 à FULL_DB au-dessus, en décibels."""
    if rms <= 0 or floor <= 0:
        return 0.0
    db = 20.0 * math.log10(rms / floor)
    return max(0.0, min(1.0, db / FULL_DB))


def sock_path():
    base = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
    return os.path.join(base, "macarchy-touchbar", "sock")


class LevelSender:
    def __init__(self, path=None, now=time.monotonic, rate=RATE_HZ):
        self.path, self.now, self.period = path or sock_path(), now, 1.0 / rate
        self.last = float("-inf")

    def send(self, level):
        t = self.now()
        if t - self.last < self.period:
            return False
        self.last = t
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                s.settimeout(0.02)
                s.connect(self.path)
                s.sendall(f"macarchy.jarvis level {level:.2f}\n".encode())
                # the bar's answer is never awaited, a level is worth less than the frame it would delay
        except OSError:
            return False
        return True
