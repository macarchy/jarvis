#!/usr/bin/env python3
"""Generate the Babel fish sprite sheets for the Jarvis mascot.

Every frame is hand-authored as an ASCII pixel map (one char = one pixel),
composed onto a fixed canvas and written as horizontal sprite sheets, one
PNG per animation state, at 1x. The shell scales them up with
nearest-neighbor so the pixels stay crisp.

States: idle (bob + blink), listening (perked, sound waves), thinking
(eyes up, thought dots), speaking (mouth cycle).
"""

import os
import struct
import zlib


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

OUT = os.path.join(os.path.dirname(__file__), "..", "assets")

# Canvas: room above the fish for thought dots / sound waves.
W, H = 36, 28

PALETTE = {
    "K": (24, 18, 8, 255),       # outline, near-black warm
    "Y": (242, 201, 76, 255),    # body yellow
    "O": (217, 154, 43, 255),    # belly shade
    "H": (250, 226, 130, 255),   # body highlight
    "F": (247, 224, 138, 255),   # fins, pale yellow
    "W": (255, 255, 255, 255),   # eye white
    "P": (24, 18, 8, 255),       # pupil
    "R": (150, 60, 40, 255),     # mouth interior
    "B": (120, 190, 255, 200),   # sound waves / bubbles, soft blue
    "b": (120, 190, 255, 120),   # fainter blue
    ".": (0, 0, 0, 0),           # transparent
}

# ---------------------------------------------------------------- the fish
#
# 26x14, facing left. Leech-like Babel fish: big eye, feathery gill stalks
# on top of the head, small pectoral fin, forked tail on the right.
# Row templates use placeholders replaced per-frame:
#   E1/E2 rows carry the eye (open, closed, up), M the mouth column.

FISH = [
    "......b.b...................",
    ".....KbKbK..................",
    "....K.K.K.K.................",
    "....KKYYYKKKK...............",
    "..KKYYYYYYYYYKKK............",
    ".KYYWWPYYYYYYYYYKK....KK....",
    "KYYWWWPYYHHYYYYYYYK..KFFK...",
    "KYWWWWPYYYYYYYYYYYYKKFFFK...",
    "KRYYYYYYYYYYYYYYYYYFFFFK....",
    "KRYYYYYYYYYYYYYYYYYFFFK.....",
    ".KYOOYYYYYYYYYYYYYYFFFFK....",
    "..KKOOOOYYYYYYYYKKKKFFFK....",
    "....KKOOOOOOKKKK.....KK.....",
    "......KKKKKK................",
]

# The gill stalks (rows 0-2) only exist on some frames; strip by default.
def fish_rows(gills=True):
    rows = [list(r) for r in FISH]
    if not gills:
        for y in range(3):
            rows[y] = list("." * len(FISH[y]))
    return rows


def close_eye(rows):
    # Replace eye whites/pupil with body + a lid line.
    for y in (5, 6, 7):
        rows[y] = [("Y" if c in "WP" else c) for c in rows[y]]
    for x, c in enumerate(rows[6]):
        if FISH[6][x] in "WP":
            rows[6][x] = "K"
    return rows


def eye_up(rows):
    # Pupil slides to the top of the eye, 2px so it reads: thinking face.
    for y in (5, 6, 7):
        rows[y] = [("W" if c == "P" else c) for c in rows[y]]
    cols = [x for x, c in enumerate(FISH[5]) if c in "WP"]
    for x in cols[-2:]:
        rows[5][x] = "P"
    return rows


def open_mouth(rows, wide=False):
    # Carve a real open mouth into the front: outline lip, red interior.
    rows[7][0] = "K"
    for y in (8, 9):
        rows[y][0] = "K"
        rows[y][1] = "R"
        rows[y][2] = "R"
    if wide:
        for y in (8, 9):
            rows[y][3] = "R"
        rows[10][0] = "K"
        rows[10][1] = "R"
        rows[10][2] = "R"
        rows[11][1] = "K"
    return rows


def sway_tail(rows):
    # Alternate tail fork position by one pixel.
    out = []
    for y, row in enumerate(rows):
        row = row[:]
        if 5 <= y <= 12:
            tail = row[20:]
            if y <= 8:
                tail = ["."] + tail[:-1]
            else:
                tail = tail[1:] + ["."]
            row = row[:20] + tail
        out.append(row)
    return out


def compose(rows, dy=0, extra=None):
    img = Frame(W, H)
    ox, oy = 4, 10 + dy
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            color = PALETTE.get(c)
            if color:
                img.set(ox + x, oy + y, color)
    for (x, y, c) in (extra or []):
        img.set(x, y, PALETTE[c])
    return img


def sheet(name, frames):
    os.makedirs(OUT, exist_ok=True)
    def get_pixel(x, y):
        return frames[x // W].get(x % W, y)
    write_png(os.path.join(OUT, f"{name}.png"), W * len(frames), H, get_pixel)
    print(f"{name}: {len(frames)} frames")


def strip_fx(rows):
    return [[("." if c in "Bb" else c) for c in row] for row in rows]


# ------------------------------------------------------------------ states

plain = strip_fx(fish_rows())

# idle: bob down/up, tail sway, occasional blink.
idle = [
    compose(plain, 0),
    compose(sway_tail(plain), 1),
    compose(plain, 0),
    compose(close_eye([r[:] for r in plain]), 0),
    compose(plain, 0),
    compose(sway_tail(plain), 1),
]

# listening: gill stalks with bubbles up, wide eye, sound waves at the left.
listen_rows = fish_rows()  # keeps the blue-tipped stalks
waves = [(2, 13, "B"), (1, 14, "B"), (0, 15, "b"), (0, 17, "b"),
         (1, 18, "B"), (2, 19, "B")]
waves2 = [(1, 12, "b"), (0, 13, "b"), (3, 14, "B"), (2, 15, "B"),
          (2, 17, "B"), (3, 18, "B"), (0, 19, "b"), (1, 20, "b")]
listening = [
    compose(listen_rows, 0, waves),
    compose(sway_tail(listen_rows), 0, waves2),
]

# thinking: eyes up, thought dots rising to the upper right.
think = eye_up([r[:] for r in plain])
dots1 = [(30, 8, "B")]
dots2 = [(30, 8, "b"), (32, 5, "B")]
dots3 = [(30, 8, "b"), (32, 5, "B"), (34, 2, "B")]
thinking = [
    compose(think, 0, dots1),
    compose(think, 1, dots2),
    compose(sway_tail(think), 0, dots3),
]

# speaking: mouth cycle with bubbles drifting from the mouth.
talk_half = open_mouth([r[:] for r in plain])
talk_wide = open_mouth([r[:] for r in plain], wide=True)
speaking = [
    compose(talk_half, 0, [(2, 17, "b")]),
    compose(talk_wide, 0, [(1, 15, "B"), (3, 12, "b")]),
    compose(talk_half, 1, [(1, 13, "B")]),
    compose(plain, 0),
]

# sleeping: eyes closed, slow bob, zZz drifting up — the dream state.
sleep_rows = close_eye([r[:] for r in plain])

def zee(x, y, faint=False):
    c = "b" if faint else "B"
    return [(x, y, c), (x + 1, y, c), (x + 2, y, c),
            (x + 1, y + 1, c),
            (x, y + 2, c), (x + 1, y + 2, c), (x + 2, y + 2, c)]

sleeping = [
    compose(sleep_rows, 1, zee(27, 9)),
    compose(sleep_rows, 1, zee(27, 9, True) + zee(30, 5)),
    compose(sleep_rows, 0, zee(30, 5, True) + zee(33, 1)),
    compose(sleep_rows, 0, zee(33, 1, True)),
]

sheet("idle", idle)
sheet("sleeping", sleeping)
sheet("listening", listening)
sheet("thinking", thinking)
sheet("speaking", speaking)
print(f"canvas {W}x{H}")
