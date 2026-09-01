#!/usr/bin/env python3
"""generate — the sprite engine: one fish configuration in, the eleven
animated sheets out.

The fish is assembled from parts (sprites/parts.py: a body with anchors,
an eye, a crest, a tail, a colourway). Every animation below is written
against the anchors, not the pixels — blink and look-up act on the eye
box whatever eye sits there, the mouth is carved at the body's lip,
the tail flexes its outer rows, the crest perks — so any combination
animates with this same code.

    generate.py [--body B1] [--eye E1] [--crest M1] [--tail T1]
                [--pal or] [--out DIR]

Canvas 72x56 at 1x; the shell scales nearest-neighbor (pixelScale 2).
"""

import os
import struct
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))

# --------------------------------------------------------------- png bits


def write_png(path, width, height, get_pixel):
    """Minimal RGBA PNG writer: get_pixel(x, y) -> (r, g, b, a)."""
    raw = b"".join(
        b"\x00" + b"".join(bytes(get_pixel(x, y)) for x in range(width))
        for y in range(height)
    )
    def chunk(tag, data):
        payload = tag + data
        return struct.pack(">I", len(data)) + payload + struct.pack(
            ">I", zlib.crc32(payload) & 0xFFFFFFFF)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        f.write(chunk(b"IEND", b""))


class Frame:
    """PIL-free stand-in: a WxH RGBA pixel grid."""
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.data = {}
    def set(self, x, y, color):
        if 0 <= x < self.w and 0 <= y < self.h and color[3] > 0:
            self.data[(x, y)] = color
    def get(self, x, y):
        return self.data.get((x, y), (0, 0, 0, 0))


OUT = os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "assets")
W, H = 72, 56            # canvas
OX, OY = 10, 22          # where the 52x28 body box sits (room above for fx)

PALETTE = {
    "K": (24, 18, 8, 255),       # outline, near-black warm
    "Y": (242, 201, 76, 255),    # body
    "O": (217, 154, 43, 255),    # belly shade
    "H": (250, 226, 130, 255),   # highlight
    "F": (247, 224, 138, 255),   # fins, pale
    "D": (196, 128, 34, 255),    # back shade
    "W": (255, 255, 255, 255),   # eye white
    "L": (214, 236, 255, 255),   # eye catchlight
    "P": (24, 18, 8, 255),       # pupil
    "R": (150, 60, 40, 255),     # mouth interior / lip
    "B": (120, 190, 255, 200),   # sound waves / bubbles, soft blue
    "b": (120, 190, 255, 175),   # fainter blue
    ".": (0, 0, 0, 0),           # transparent
    "1": (255, 99, 99, 235),     # confetti red
    "2": (99, 200, 120, 235),    # confetti green
    "3": (255, 214, 90, 235),    # confetti gold
    "4": (120, 190, 255, 235),   # confetti blue
    "G": (70, 70, 80, 255),      # headphone plastic
}

import parts  # noqa: E402  (needs PALETTE/W/H above)


def hexrgb(h):
    return (int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16), 255)


def palette_for(pal):
    p = dict(PALETTE)
    for ch, h in parts.PALETTES[pal][1].items():
        p[ch] = hexrgb(h)
    return p


# ------------------------------------------------------- part-wise moves
#
# Everything below takes the composed 52x28 rows and the config, and
# edits by anchor. `box(rows, anchor, size)` iterates a part's cells.


def grid(rows):
    return [list(r) for r in rows]


def text(g):
    return ["".join(r) for r in g]


def eye_cells(cfg):
    ax, ay = parts.anchors(cfg)["eye"]
    w, h = parts.EYE_BOX
    return [(ax + x, ay + y) for y in range(h) for x in range(w)
            if 0 <= ay + y < parts.BH and 0 <= ax + x < parts.BW]


def close_eye(rows, cfg):
    # Whites and pupil become flesh; the eye's middle row becomes a lid.
    g = grid(rows)
    ax, ay = parts.anchors(cfg)["eye"]
    mid = ay + parts.EYE_BOX[1] // 2
    for x, y in eye_cells(cfg):
        if g[y][x] in "WLP":
            g[y][x] = "K" if y == mid else "Y"
    return text(g)


def half_eyes(rows, cfg):
    # Heavy lids: the top half closes, the lower half stays.
    g = grid(rows)
    ax, ay = parts.anchors(cfg)["eye"]
    mid = ay + parts.EYE_BOX[1] // 2
    for x, y in eye_cells(cfg):
        if g[y][x] in "WLP" and y < mid:
            g[y][x] = "K" if y == mid - 1 else "Y"
    return text(g)


def eye_up(rows, cfg):
    # The pupil slides up two rows inside the white: thinking, curious.
    g = grid(rows)
    pupils = [(x, y) for x, y in eye_cells(cfg) if g[y][x] == "P"]
    for x, y in pupils:
        g[y][x] = "W"
    for x, y in pupils:
        ty = y - 2
        if 0 <= ty and g[ty][x] in "WL":
            g[ty][x] = "P"
    return text(g)


def open_mouth(rows, cfg, wide=False):
    # Carve the lip open: outline, red interior, wider and lower if wide.
    g = grid(rows)
    mx, my = parts.anchors(cfg)["mouth"]
    for y in (my, my + 1):
        g[y][mx] = "K"
        g[y][mx + 1] = "R"
        g[y][mx + 2] = "R"
    if wide:
        for y in (my, my + 1):
            g[y][mx + 3] = "R"
        g[my + 2][mx] = "K"
        g[my + 2][mx + 1] = "R"
        g[my + 2][mx + 2] = "R"
        if g[my + 3][mx + 1] != ".":
            g[my + 3][mx + 1] = "K"
    return text(g)


def sway_tail(rows, cfg):
    # The tail's upper rows slide right, its lower rows left — only past
    # the attachment columns, so the peduncle never tears.
    g = grid(rows)
    ax, ay = parts.anchors(cfg)["tail"]
    w, h = parts.TAIL_BOX
    x0 = ax + 3
    for y in range(ay, min(ay + h, parts.BH)):
        seg = g[y][x0:x0 + w]
        if y < ay + h // 3:
            seg = ["."] + seg[:-1]
        elif y >= ay + 2 * h // 3:
            seg = seg[1:] + ["."]
        else:
            continue
        g[y][x0:x0 + w] = seg[:len(g[y][x0:x0 + w])]
    return text(g)


def worried_brow(rows, cfg):
    # A slanted brow pressing on the eye, carved in the flesh above it.
    g = grid(rows)
    ax, ay = parts.anchors(cfg)["eye"]
    for dx, dy in ((2, -1), (3, -1), (4, 0), (5, 0)):
        x, y = ax + dx, ay + dy
        if 0 <= y < parts.BH and g[y][x] not in ".K":
            g[y][x] = "K"
    return text(g)


def headphones(rows, cfg):
    # Band one pixel clear of the crown, a strut down to a cup on the cheek.
    g = grid(rows)
    hx, hy, hw = parts.anchors(cfg)["head"]
    ax, ay = parts.anchors(cfg)["eye"]
    for x in range(hx, hx + hw):
        g[hy - 2][x] = "G"
    g[hy - 1][hx - 1] = "G"
    g[hy - 1][hx + hw] = "G"
    for y in range(hy, ay + 2):
        g[y][hx + hw] = "G"
    cx, cy = hx + hw, ay + 3
    for dx, dy in ((0, 0), (-1, 1), (0, 1), (1, 1), (0, 2)):
        g[cy + dy][cx + dx] = "G"
    g[cy + 1][cx] = "K"
    return text(g)


# ----------------------------------------------------------- composition


def frame(rows, dy=0, extra=None, pal=None):
    """Body rows onto the canvas, bobbed by dy, plus canvas-coord fx."""
    pal = pal or PALETTE
    img = Frame(W, H)
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            color = pal.get(c)
            if color and color[3]:
                img.set(OX + x, OY + dy + y, color)
    for (x, y, c) in (extra or []):
        img.set(x, y, pal[c])
    return img


def sheet(out, name, frames):
    os.makedirs(out, exist_ok=True)
    def get_pixel(x, y):
        return frames[x // W].get(x % W, y)
    write_png(os.path.join(out, f"{name}.png"), W * len(frames), H, get_pixel)


# fx, in canvas coords (the head sits left, the crown around y=27)
def zee(x, y, faint=False):
    c = "b" if faint else "B"
    return [(x, y, c), (x + 1, y, c), (x + 2, y, c), (x + 1, y + 1, c),
            (x, y + 2, c), (x + 1, y + 2, c), (x + 2, y + 2, c)]


def qmark(x, y, faint=False):
    c = "b" if faint else "B"
    return [(x + 1, y, c), (x + 2, y, c), (x, y + 1, c), (x + 3, y + 1, c),
            (x + 3, y + 2, c), (x + 2, y + 3, c), (x + 2, y + 4, c), (x + 2, y + 6, c)]


def sparkle(x, y):
    return [(x, y - 1, "3"), (x - 1, y, "3"), (x, y, "3"), (x + 1, y, "3"), (x, y + 1, "3")]


def build(cfg, out):
    pal = palette_for(cfg["pal"])
    mx, my = parts.anchors(cfg)["mouth"]
    ax, ay = parts.anchors(cfg)["eye"]
    plain = parts.compose(cfg)
    perked = parts.compose(cfg, crest_dy=-1)
    bare = parts.compose(cfg, crest=False)
    F = lambda rows, dy=0, extra=None: frame(rows, dy, extra, pal)  # noqa: E731

    sheets = {}
    sheets["idle"] = [
        F(plain, 0), F(sway_tail(plain, cfg), 1), F(plain, 0),
        F(close_eye(plain, cfg), 0), F(plain, 0), F(sway_tail(plain, cfg), 1),
    ]
    wx, wy = OX + mx - 6, OY + my - 2
    waves = [(wx + 2, wy + 1, "B"), (wx + 1, wy + 2, "B"), (wx, wy + 3, "b"),
             (wx, wy + 5, "b"), (wx + 1, wy + 6, "B"), (wx + 2, wy + 7, "B")]
    waves2 = [(wx + 1, wy, "b"), (wx, wy + 1, "b"), (wx + 3, wy + 2, "B"), (wx + 2, wy + 3, "B"),
              (wx + 2, wy + 5, "B"), (wx + 3, wy + 6, "B"), (wx, wy + 7, "b"), (wx + 1, wy + 8, "b")]
    sheets["listening"] = [F(perked, 0, waves), F(sway_tail(perked, cfg), 0, waves2)]

    think = eye_up(plain, cfg)
    dots = [(58, 16, "B"), (62, 10, "B"), (66, 4, "B")]
    sheets["thinking"] = [
        F(think, 0, dots[:1]), F(think, 1, [(58, 16, "b"), dots[1]]),
        F(sway_tail(think, cfg), 0, [(58, 16, "b"), (62, 10, "B"), dots[2]]),
    ]
    half, wide = open_mouth(plain, cfg), open_mouth(plain, cfg, wide=True)
    bx, by = OX + mx - 3, OY + my
    sheets["speaking"] = [
        F(half, 0, [(bx, by + 2, "b")]),
        F(wide, 0, [(bx - 1, by, "B"), (bx + 1, by - 3, "b")]),
        F(half, 1, [(bx - 1, by - 2, "B")]),
        F(plain, 0),
    ]
    asleep = close_eye(plain, cfg)
    sheets["sleeping"] = [
        F(asleep, 1, zee(52, 18)),
        F(asleep, 1, zee(52, 18, True) + zee(58, 10)),
        F(asleep, 0, zee(58, 10, True) + zee(64, 2)),
        F(asleep, 0, zee(64, 2, True)),
    ]
    tired = half_eyes(plain, cfg)
    dx, dy = OX + ax + 13, OY + ay + 1
    sheets["tired"] = [F(tired, 2, [(dx, dy, "B")]),
                       F(sway_tail(tired, cfg), 3, [(dx, dy + 1, "B"), (dx, dy - 1, "b")])]
    dnd = headphones(bare, cfg)
    sheets["dnd"] = [F(dnd, 0), F(sway_tail(dnd, cfg), 1)]
    worried = worried_brow(plain, cfg)
    sheets["worried"] = [F(worried, 0, [(dx - 1, dy, "B")]), F(worried, 1, [(dx - 1, dy + 2, "B")])]
    proud = close_eye(plain, cfg)
    sheets["proud"] = [F(proud, -1, sparkle(14, 12) + sparkle(60, 20)),
                       F(sway_tail(proud, cfg), -2, sparkle(20, 8) + sparkle(56, 26))]
    curious = eye_up(plain, cfg)
    sheets["curious"] = [F(curious, 0, qmark(56, 4)), F(sway_tail(curious, cfg), 1, qmark(56, 4, True))]
    confetti1 = [(12, 8, "1"), (28, 4, "3"), (44, 10, "2"), (56, 6, "4"), (36, 14, "1")]
    confetti2 = [(16, 12, "3"), (24, 8, "4"), (40, 4, "1"), (52, 12, "2"), (62, 8, "3")]
    confetti3 = [(10, 6, "2"), (32, 10, "1"), (48, 8, "3"), (60, 14, "4"), (20, 4, "2")]
    sheets["celebrate"] = [F(plain, -2, confetti1), F(sway_tail(plain, cfg), -4, confetti2), F(plain, -3, confetti3)]

    for name, frames in sheets.items():
        sheet(out, name, frames)
    return sheets


def parse(argv):
    cfg = dict(parts.DEFAULT, pal=parts.DEFAULT_PALETTE)
    out = OUT
    it = iter(argv)
    for a in it:
        if a == "--out":
            out = next(it)
        elif a.startswith("--") and a[2:] in cfg:
            v = next(it)
            lib = parts.AXES.get(a[2:]) or (parts.PALETTES if a[2:] == "pal" else None)
            if lib is None or v not in lib:
                sys.exit(f"unknown {a[2:]}: {v} (choose from {', '.join(lib or [])})")
            cfg[a[2:]] = v
        else:
            sys.exit(__doc__)
    return cfg, out


def main(argv):
    cfg, out = parse(argv)
    sheets = build(cfg, out)
    print(" ".join(f"{k}={v}" for k, v in cfg.items()),
          "→", ", ".join(f"{n}:{len(f)}" for n, f in sheets.items()), f"canvas {W}x{H}")


if __name__ == "__main__":
    main(sys.argv[1:])
