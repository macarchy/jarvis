#!/usr/bin/env python3
"""check — every shape configuration through every part-wise move, and
three attachment rules measured, not eyeballed:

  1. no exception from any animation function;
  2. one connected component (8-neighbour) once fx colours (B/b) are
     ignored — nothing floats;
  3. the tail's attachment rows (box rows 4-8, cols 1-2) touch body.

Exit status = number of failing (config, variant) pairs.
"""

import itertools
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
import generate  # noqa: E402
import parts  # noqa: E402

FX = set("Bb1234")


def components(rows):
    cells = {(x, y) for y, r in enumerate(rows) for x, c in enumerate(r) if c != "." and c not in FX}
    seen, n = set(), 0
    for start in cells:
        if start in seen:
            continue
        n += 1
        stack = [start]
        seen.add(start)
        while stack:
            x, y = stack.pop()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    p = (x + dx, y + dy)
                    if p in cells and p not in seen:
                        seen.add(p)
                        stack.append(p)
    return n


def tail_attached(rows, cfg):
    ax, ay = parts.anchors(cfg)["tail"]
    body = parts.BODIES[cfg["body"]][1]
    hits = 0
    for y in range(ay + 4, ay + 9):
        if 0 <= y < parts.BH and any(body[y][x] != "." for x in (ax + 1, ax + 2) if x < parts.BW):
            hits += 1
    return hits >= 3


def variants_of(cfg):
    plain = parts.compose(cfg)
    yield "plain", plain
    yield "sway", generate.sway_tail(plain, cfg)
    yield "fold", generate.fold_tail(plain, cfg)
    yield "blink", generate.close_eye(plain, cfg)
    yield "eye_up", generate.eye_up(plain, cfg)
    yield "half", generate.half_eyes(plain, cfg)
    yield "mouth", generate.open_mouth(plain, cfg)
    yield "mouth_wide", generate.open_mouth(plain, cfg, wide=True)
    yield "perked", parts.compose(cfg, crest_dy=-1)
    yield "headphones", generate.headphones(parts.compose(cfg, crest=False), cfg)
    yield "brow", generate.worried_brow(plain, cfg)


def main():
    fails = []
    for b, e, m, t in itertools.product(parts.BODIES, parts.EYES, parts.CRESTS, parts.TAILS):
        cfg = {"body": b, "eye": e, "crest": m, "tail": t, "pal": "or"}
        try:
            for name, rows in variants_of(cfg):
                n = components(rows)
                if n != 1:
                    fails.append((b, e, m, t, name, f"{n} composantes"))
            if not tail_attached(parts.compose(cfg), cfg):
                fails.append((b, e, m, t, "tail", "queue sans pédoncule"))
        except Exception as ex:  # noqa: BLE001
            fails.append((b, e, m, t, "exception", repr(ex)))
    by = {}
    for f in fails:
        by.setdefault((f[0], f[2] if f[4] in ("plain", "perked") else f[3] if f[4] == "tail" else f[4]), []).append(f)
    for key, items in sorted(by.items()):
        print(f"{key[0]} × {key[1]}: {len(items)} — ex. {items[0][1]} {items[0][2]} {items[0][3]} {items[0][4]}: {items[0][5]}")
    print(f"{len(fails)} échec(s) sur {4**4} configurations × 11 variantes")
    return min(len(fails), 255)


if __name__ == "__main__":
    sys.exit(main())
