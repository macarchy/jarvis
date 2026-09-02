#!/usr/bin/env python3
"""Le niveau de l'oreille vers la Touch Bar : l'échelle et l'envoi, sans
micro ni barre — une prise Unix éphémère joue macarchy-dfr."""
import os
import socket
import sys
import tempfile
import threading

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(
    os.path.realpath(__file__))), "bin"))

import jarvis_wake_level as wl  # noqa: E402

fails = []


def check(name, got, want):
    if got != want:
        fails.append(f"  {name}: attendu {want!r}, obtenu {got!r}")


check("au plancher, zéro", wl.level_of(60.0, 60.0), 0.0)
check("30 dB au-dessus, plein", wl.level_of(60.0 * 10 ** 1.5, 60.0), 1.0)
check("plus haut encore, borné", wl.level_of(60.0 * 1000, 60.0), 1.0)
check("sous le plancher, zéro", wl.level_of(10.0, 60.0), 0.0)
check("silence absolu, zéro", wl.level_of(0.0, 60.0), 0.0)
check("plancher nul, zéro", wl.level_of(50.0, 0.0), 0.0)
half = wl.level_of(60.0 * 10 ** 0.75, 60.0)
check("15 dB, moitié", round(half, 3), 0.5)

# ---- l'envoi
d = tempfile.mkdtemp()
path = os.path.join(d, "sock")
srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
srv.bind(path)
srv.listen(4)
seen = []


def serve():
    while True:
        try:
            c, _ = srv.accept()
        except OSError:
            return
        with c:
            seen.append(c.makefile().readline().strip())
            c.sendall(b"ok\n")


thread = threading.Thread(target=serve, daemon=True)
thread.start()
clock = [0.0]
s = wl.LevelSender(path=path, now=lambda: clock[0])
check("premier envoi", s.send(0.5), True)
check("la ligne du protocole", seen[-1], "macarchy.jarvis level 0.50")
clock[0] = 0.05
check("10 Hz : le second est retenu", s.send(0.6), False)
clock[0] = 0.11
check("après 100 ms il passe", s.send(0.6), True)
check("deux lignes reçues", len(seen), 2)
srv.shutdown(socket.SHUT_RDWR)      # wakes the blocked accept() with an error
srv.close()
thread.join(1.0)
clock[0] = 1.0
check("sans daemon, rien ne casse", s.send(0.7), False)
os.unlink(path)
check("sans prise, rien ne casse", wl.LevelSender(path=path, now=lambda: 9.0).send(0.1), False)

for line in fails:
    print(line)
print(f"{len(fails)} cas raté(s) sur le niveau")
sys.exit(1 if fails else 0)
