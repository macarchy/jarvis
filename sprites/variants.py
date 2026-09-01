#!/usr/bin/env python3
"""variants — four deliberately different fish at twice the native
resolution (52x28 body on a 72x56 canvas, shown at pixelScale 2 — the
same size on screen as today's 26x14 at 4), for the human to judge.

Each is one idle frame. The current fish is rendered alongside, upscaled
2x, as the control. Output: sprites/variants/<name>.png + sheet.png.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
import generate  # noqa: E402
from preview import read_png  # noqa: E402

CW, CH = 72, 56          # canvas
BW, BH = 52, 28          # body box
OUT = os.path.join(os.path.dirname(os.path.realpath(__file__)), "variants")


def pad(rows):
    rows = [r.ljust(BW, ".") for r in rows]
    assert all(len(r) == BW for r in rows), [len(r) for r in rows if len(r) != BW]
    while len(rows) < BH:
        rows.append("." * BW)
    assert len(rows) == BH, len(rows)
    return rows


# ---------------------------------------------------------------------------
# A — « Rondouillard » : chibi tamagotchi, corps rond, œil immense avec
# reflet, joues, petites nageoires. Le mignon assumé.
RONDOUILLARD = pad([
    ".................KKKKKKK",
    "..............KKKYYYHHHKKK",
    "............KKYYYYHHHHHYYKK",
    "..........KKYYYYYYHHHHYYYYYKK",
    ".........KYYYYYYYYYHHYYYYYYYYK",
    "........KYYYKKKKYYYYYYYYYYYYYYK",
    ".......KYYKKWWWWKKYYYYYYYYYYYYYK.......KK",
    "......KYYKWWWWWWWWKYYYYYYYYYYYYYK.....KFFK",
    "......KYKWWWLLWWWWWKYYYYYYYYYYYYYK...KFFFK",
    ".....KYYKWWLLWWPPWWKYYYYYYYYYYYYYYK.KFFFFK",
    ".....KYYKWWWWWWPPPWKYYYYYYYYYYYYYYKKFFFFK",
    ".....KYYKWWWWWWPPPWKYYYYYYYYYYYYYYFFFFFK",
    ".....KYYYKWWWWWWWWKYYYYYYYYYYYYYYYFFFFK",
    ".....KYYYYKKWWWWKKYYYYYYYYYYYYYYYFFFFFK",
    ".....KRRYYRRKKKKYYYYYYYYYYYYYYYYYYFFFFFK",
    ".....KRRYYYRRYYYYYYKFFFKYYYYYYYYYYKFFFFK",
    "......KYYYYYYYYYYYKFFFFFKYYYYYYYYYKKFFFFK",
    "......KYOOYYYYYYYYKFFFFFKYYYYYYYYYK.KFFFFK",
    ".......KOOOOYYYYYYYKFFFKYYYYYYYYYK...KFFFK",
    "........KOOOOOOYYYYYKKKYYYYYYYYYK.....KFFK",
    ".........KOOOOOOOOOYYYYYYYYYYYYK.......KK",
    "..........KKOOOOOOOOOOOOYYYYYKK",
    "............KKOOOOOOOOOOOOKKK",
    "..............KKKOOOOOOKKK",
    ".................KKKKKKK",
])

# ---------------------------------------------------------------------------
# B — « Élancé » : fusiforme, dos sombre (contre-ombrage), dorsale, ligne
# de lumière, queue en croissant. Le poisson élégant.
ELANCE = pad([
    "",
    "",
    "",
    "",
    "",
    "",
    ".........................KK",
    "........................KFFK",
    ".......................KFFFFK",
    ".............KKKKKKKKKKFFFFFFKKKKK",
    ".........KKKKDDDDDDDDDDDDDDDDDDDDDKKKK",
    "......KKKDDDDDDDDDDDDDDDDDDDDDDDDDDDYYKKK",
    "....KKYYDDKKKDYYYYYYYYYYYYYYYYYYYYYYYYYYKK....KK",
    "..KKYYYYKWWWKYYYYYYYYYYYYYYYYYYYYYYYYYYYYKK..KFFK",
    ".KYYYYYKWLWPKYYYYYYYYYYYYYYYYYYYYYYYYYYYYYKKKFFFK",
    "KYYYYYYKWWPPKYYYYYHHHHHHHHHHHHHHHHHHHYYYYYYFFFFK",
    "KRYYYYYYKKKYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYFFFFK",
    "KRYYYYYYYYYYYYYYKFFFKYYYYYYYYYYYYYYYYYYYYYFFFFK",
    ".KYYYYYYYYYYYYYYKFFFFKYYYYYYYYYYYYYYYYYYYYKFFFFK",
    "..KKOOOOOOOOOOOOOKFFFKOOOOOOOOOOOOOOOOOOKKKKFFFK",
    "....KKOOOOOOOOOOOOKKKOOOOOOOOOOOOOOOOKKKK...KFFK",
    "......KKKOOOOOOOOOOOOOOOOOOOOOOOKKKKK.......KK",
    ".........KKKKKKKKKKKKKKKKKKKKKKK",
])

# ---------------------------------------------------------------------------
# C — « Babel » : fidèle au poisson du Guide — corps de sangsue effilé en
# pointe, panache de branchies sur la tête, grand œil, ventre clair.
BABEL = pad([
    ".........B..B..B",
    "........KB.KB.KB",
    ".......KYKKYKKYK",
    "......KKYYYYYYYKK",
    "....KKYYYHHHHHYYYKK",
    "...KYYYHHHHHHHHHHYYKKK",
    "..KYYHHHHHHHHHHHHHYYYYKKKK",
    ".KYYHHKKKKHHHHHHHHHYYYYYYYKKKK",
    ".KYHKWWWWWKHHHHHHHHYYYYYYYYYYYKKKK",
    "KYHKWWLLWWWKHHHHHHHYYYYYYYYYYYYYYYKKKK",
    "KYHKWWLLWPPWKHHHHHHYYYYYYYYYYYYYYYYYYYKKKK",
    "KYHKWWWWWPPPKHHHHHYYYYYYYYYYYYYYYYYYYYYYYYKKK",
    "KYYKWWWWWWPPKYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYKKK",
    "KRYYKWWWWWWKYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYKKK",
    "KRYYYKKKKKKYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYOOOOKK",
    "KYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYOOOOOOOKK",
    ".KYYYYYYYYYYYYKFFKYYYYYYYYYYYYYYYYYYYOOOOOOOOKKK",
    ".KYOOYYYYYYYYKFFFFKYYYYYYYYYYYYYOOOOOOOOOOKKK",
    "..KOOOOYYYYYYKFFFFKYYYYYYYYYOOOOOOOOOOKKKK",
    "...KOOOOOOOYYYKFFKOOOOOOOOOOOOOOOOKKKK",
    "....KKOOOOOOOOOKKOOOOOOOOOOOOKKKKK",
    "......KKOOOOOOOOOOOOOOOOOKKKKK",
    "........KKKOOOOOOOOOKKKKK",
    "...........KKKKKKKKKK",
])

# ---------------------------------------------------------------------------
# D — « Game Boy » : quatre tons, contour double, formes franches, œil
# sans blanc. Le rétro net.
GAMEBOY = pad([
    "",
    "",
    "",
    "",
    "",
    "..........KKKKKKKKKKKKKKK",
    "........KKYYYYYYYYYYYYYYYKK",
    "......KKYYYYYYYYYYYYYYYYYYYKK",
    ".....KKYYYYYYYYYYYYYYYYYYYYYKK",
    "....KKYYYKKKKYYYYYYYYYYYYYYYYKK.........KKK",
    "...KKYYYKHHHHKYYYYYYYYYYYYYYYYKK......KKOOKK",
    "...KYYYYKHKKHKYYYYYYYYYYYYYYYYYKK....KKOOOOK",
    "..KKYYYYKHKKHKYYYYYYYYYYYYYYYYYYKK..KKOOOOKK",
    "..KYYYYYKHHHHKYYYYYYYYYYYYYYYYYYYKKKKOOOOKK",
    "..KYYYYYYKKKKYYYYYYYYYYYYYYYYYYYYYOOOOOOKK",
    "..KKKYYYYYYYYYYYYYYYYYYYYYYYYYYYYYOOOOOKK",
    "..KYYYYYYYYYYYYYKKKYYYYYYYYYYYYYYYOOOOOOKK",
    "..KYYYYYYYYYYYYKOOOKYYYYYYYYYYYYYKKKOOOOKK",
    "..KKOOOYYYYYYYYKOOOKYYYYYYYYYYYYKK..KKOOOOK",
    "...KKOOOOOYYYYYKKKKYYYYYYYYYYYKK.....KKOOKK",
    "....KKOOOOOOOOOOOOOOOOOOOOOOOKK........KKK",
    ".....KKOOOOOOOOOOOOOOOOOOOOKK",
    ".......KKOOOOOOOOOOOOOOOKKK",
    ".........KKKKKKKKKKKKKKK",
])

VARIANTS = [("A-rondouillard", RONDOUILLARD), ("B-elance", ELANCE),
            ("C-babel", BABEL), ("D-gameboy", GAMEBOY)]


def compose(rows):
    img = generate.Frame(CW, CH)
    ox, oy = (CW - BW) // 2, CH - BH - 6
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            color = generate.PALETTE.get(c)
            if color:
                img.set(ox + x, oy + y, color)
    return img


def current_2x():
    """Today's idle frame 0, doubled: the control, at the same on-screen size."""
    w, h, px = read_png(os.path.join(generate.OUT, "idle.png"))
    img = generate.Frame(CW, CH)
    ox, oy = (CW - generate.W * 2) // 2, CH - generate.H * 2
    for y in range(generate.H):
        for x in range(generate.W):
            c = px[y][x]
            if c[3]:
                for dy in (0, 1):
                    for dx in (0, 1):
                        img.set(ox + 2 * x + dx, oy + 2 * y + dy, c)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    frames = [("actuel-2x", current_2x())] + [(n, compose(r)) for n, r in VARIANTS]
    for name, img in frames:
        generate.write_png(os.path.join(OUT, f"{name}.png"), CW, CH, img.get)
    def px(x, y):
        return frames[x // CW][1].get(x % CW, y)
    generate.write_png(os.path.join(OUT, "sheet.png"), CW * len(frames), CH, px)
    print("variants:", ", ".join(n for n, _ in frames))


if __name__ == "__main__":
    main()
