#!/usr/bin/env python3
"""parts — the fish as pieces: a body with fixed anchors, and swappable
eyes, crests and tails drawn on their own small grids. compose() stacks
them (tail, body, crest, eye) into the 52x28 body box used by
variants.py, so every combination lands on the same animation hooks:
the eye socket (blink, look up), the mouth column (speak), the tail
attachment (sway), the crest base (flutter).

Run it to render one PNG per axis variant and the transparent layers
the configurator page stacks in the browser.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
import generate  # noqa: E402
import variants  # noqa: E402

BW, BH = variants.BW, variants.BH
OUT = os.path.join(os.path.dirname(os.path.realpath(__file__)), "parts_out")

# ---------------------------------------------------------------- bodies
#
# Every body keeps its head top on row 5 (crests sit on it), fills its
# eye socket with flesh, and closes its right edge at a peduncle where
# every tail attaches. Anchors, in body coords:
#   eye   top-left of the 11x8 eye box
#   crest top-left of the 6-row crest box
#   tail  top-left of the 12x13 tail box (its cols 1-2 overlap the edge)
#   mouth the lip column (open_mouth carves cols mouth.x..+2)
#   head  (x, y, w): the crown line the headphones band sits above

BODIES = {
    "B1": ("Babel", variants.pad([
        "", "", "", "", "",
        "........KYYYYYYYYYYYYYYK",
        ".......KKYYYYYYYYYYYYYYYYKK",
        ".....KKYYYHHHHHHHHYYYYYYYYKKK",
        "....KYYYHHHHHHHHHHHHYYYYYYYYYKK",
        "...KYYHYYYYYHHHHHHHHHYYYYYYYYYYKK",
        "..KYYHYYYYYYHHHHHHHHYYYYYYYYYYYYKK",
        ".KYYHYYYYYYYYHHHHHHHYYYYYYYYYYYYYYK",
        ".KYHYYYYYYYYYYHHHHHHYYYYYYYYYYYYYYYK",
        "KYYHYYYYYYYYYYHHHHHYYYYYYYYYYYYYYYYYK",
        "KRYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYK",
        "KRYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYK",
        "KYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYK",
        ".KYYYYYYYYYYYYYYKFFFKYYYYYYYYYYYYYYYYK",
        ".KYOOYYYYYYYYYYKFFFFFKYYYYYYYYYYYYYYK",
        "..KOOOOYYYYYYYYKFFFFFKYYYYYYYYYYYYYK",
        "...KOOOOOOYYYYYYKFFFKYYYYYYYYYYOOOKK",
        "....KKOOOOOOOOOOOKKKOOOOOOOOOOOOKK",
        "......KKOOOOOOOOOOOOOOOOOOOOOKKK",
        "........KKKOOOOOOOOOOOOOOKKKK",
        "...........KKKKKKKKKKKKKK",
    ]), {"eye": (4, 9), "crest": (7, 0), "tail": (35, 9), "mouth": (0, 14), "head": (8, 5, 16)}),

    "B2": ("Rond", variants.pad([
        "", "", "", "", "",
        "...........KKKKKKKK",
        "........KKKYYYHHHHKKK",
        "......KKYYYYYHHHHHYYKK",
        ".....KYYYYYYYHHHHYYYYYK",
        "....KYYYYYYYYYHHYYYYYYYK",
        "...KYYYYYYYYYYYYYYYYYYYYK",
        "..KYYYYYYYYYYYYYYYYYYYYYYK",
        "..KYYYYYYYYYYYYYYYYYYYYYYYK",
        ".KYYYYYYYYYYYYYYYYYYYYYYYYYK",
        "KRYYYYYYYYYYYYYYYYYYYYYYYYYYK",
        "KRYYYYYYYYYYYYYYYYYYYYYYYYYYK",
        "KYRRYYYYYYYYYYYKFFFKYYYYYYYYK",
        ".KYRRYYYYYYYYYKFFFFFKYYYYYYYK",
        ".KYYYYYYYYYYYYKFFFFFKYYYYYYK",
        "..KYOOYYYYYYYYYKFFFKYYYYYYK",
        "..KOOOOYYYYYYYYYKKKYYYYYYK",
        "...KOOOOOOYYYYYYYYYYYYYK",
        "....KOOOOOOOOOYYYYYYYKK",
        ".....KKOOOOOOOOOOOOKK",
        ".......KKOOOOOOOKKK",
        ".........KKKKKKKK",
    ]), {"eye": (4, 9), "crest": (8, 0), "tail": (26, 9), "mouth": (0, 14), "head": (11, 5, 8)}),

    "B3": ("Élancé", variants.pad([
        "", "", "", "", "",
        ".............KKKKKKKKKKKKKKKKK",
        ".........KKKKDDDDDDDDDDDDDDDDDKKKK",
        "......KKKDDDDDDDDDDDDDDDDDDDDDDDDDYYKK",
        "....KKYYDDYYYYYYYYYYYYYYYYYYYYYYYYYYYYK",
        "..KKYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYK",
        ".KYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYK",
        "KYYYYYYYYYYYYYYHHHHHHHHHHHHHHHHHHHYYYYYYK",
        "KRYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYK",
        "KRYYYYYYYYYYYYYKFFFKYYYYYYYYYYYYYYYYYYYYK",
        ".KYYYYYYYYYYYYYKFFFFKYYYYYYYYYYYYYYYYYYK",
        "..KKOOOOOOOOOOOOKFFFKOOOOOOOOOOOOOOOOKKK",
        "....KKOOOOOOOOOOOKKKOOOOOOOOOOOOOOKKK",
        "......KKKOOOOOOOOOOOOOOOOOOOOOOKKK",
        ".........KKKKKKKKKKKKKKKKKKKKK",
    ]), {"eye": (3, 8), "crest": (12, 0), "tail": (38, 7), "mouth": (0, 12), "head": (13, 5, 17)}),

    "B4": ("Anguille", variants.pad([
        "", "", "", "", "",
        "..........KKKKKKK",
        "........KKYYYYYYYKKKK",
        "......KKYYYHHHHHHYYYYKKKKK",
        "....KKYYYYHHHHHHHHYYYYYYYYKKKKKK",
        "...KYYYYYYYYYYYYYYYYYYYYYYYYYYYYKKKKK",
        "..KYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYK",
        ".KYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYK",
        "KRYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYK",
        "KRYYYYYYYYYYYKFFKYYYYYYYYYYYYOOOOOOOOOOK",
        ".KYOOYYYYYYYKFFFFKYYYYYYOOOOOOOOOOOOOKK",
        "..KOOOOOYYYYYKFFKOOOOOOOOOOOOOOOOKKKK",
        "...KKOOOOOOOOOKKOOOOOOOOOOOOKKKK",
        ".....KKKOOOOOOOOOOOOOOOKKKKK",
        "........KKKKKKKKKKKKKKK",
    ]), {"eye": (3, 7), "crest": (9, 0), "tail": (37, 7), "mouth": (0, 12), "head": (10, 5, 7)}),
}

EYE_BOX, CREST_BOX, TAIL_BOX = (11, 8), (26, 6), (12, 13)

# ------------------------------------------------------------------ eyes
EYES = {
    "E1": ("Grand", [            # C2's: big white, catchlight, pupil back
        "...KKKKK",
        "..KWWWWWK",
        ".KWWLLWWWK",
        "KWWLLWWPPWK",
        "KWWWWWWPPPK",
        "KWWWWWWWPPK",
        ".KWWWWWWWK",
        "..KKKKKKK",
    ]),
    "E2": ("Amande", [           # narrower, a lid line: calmer, older
        "",
        "...KKKKKK",
        "..KWWLLWWKK",
        ".KWWLLWWPPWK",
        "KWWWWWWPPPK",
        ".KWWWWWWPPK",
        "..KKKKKKKK",
        "",
    ]),
    "E3": ("Rond", [             # kawaii: round, huge dark pupil
        "...KKKKK",
        "..KWWWWWK",
        ".KWWLLWPPK",
        "KWWLLWPPPPK",
        "KWWWWPPPPPK",
        "KWWWWWPPPPK",
        ".KWWWWPPPK",
        "..KKKKKKK",
    ]),
    "E4": ("Anneau", [           # no white: a ring with one catchlight
        "",
        "....KKKK",
        "...KHHHHK",
        "..KHKKKKHK",
        "..KHKKLKHK",
        "...KHHHHK",
        "....KKKK",
        "",
    ]),
}

# ---------------------------------------------------------------- crests
CRESTS = {
    "M1": ("Éventail", [          # C2's five filaments fanning back
        ".......B....B....B",
        "......KY...KY...KY...B",
        ".....KYK..KYK..KYK..KY",
        "...B.KYK.KYK..KYK..KY",
        "..KYKKYYKKYKKKYK..KY",
        "..................KY",
    ]),
    "M2": ("Voile", [             # one sail sweeping back, its own ink
        ".........KK",             # base sits ON the head outline
        "........KFFK",
        ".......KFFFFKK",
        "......KFFFFFFFKK",
        ".....KFFFFFFFFFFKK",
        "....KKKKKKKKKKKKKKK",
    ]),
    "M3": ("Mohawk", [            # eight short filaments, blue tips
        "",
        "",
        "..B.B.B.B.B.B.B.B",
        "..Y.Y.Y.Y.Y.Y.Y.Y",
        ".KYKYKYKYKYKYKYKYK",
        "",
    ]),
    "M4": ("Antennes", [          # two long stalks sweeping back
        "..........B",
        "........KYK.....B",
        ".......KYK....KYK",
        "......KYK....KYK",
        ".....KYK....KYK",
        "....KYK....KYK",
    ]),
}

# ----------------------------------------------------------------- tails
TAILS = {
    "T1": ("Fourche", [           # C2's fork
        "",
        ".....KK",
        "....KFFK",
        "...KFFFK",
        "..KKFFFK",
        "..FFFFK",
        "..FFFK",
        "..FFFFK",
        "..KFFFFK",
        "...KFFFK",
        "....KFFK",
        ".....KK",
    ]),
    "T2": ("Éventail", [          # rounded fan, folds shaded at the base
        "",
        ".....KKKK",
        "...KKFFFFK",
        "..KOFFFFFFK",
        ".KKOOFFFFFFK",
        ".KOOOFFFFFFK",
        ".KOOOFFFFFFK",
        ".KOOOFFFFFFK",
        ".KKOOFFFFFFK",
        "..KOFFFFFFK",
        "...KKFFFFK",
        ".....KKKK",
    ]),
    "T3": ("Croissant", [         # thin, pointed lobes
        "........KK",
        ".......KFK",
        "......KFFK",
        ".....KFFK",
        "..KKKFFK",
        ".KFFFFK",
        ".KFFFK",
        ".KFFFFK",
        "..KKKFFK",
        ".....KFFK",
        "......KFFK",
        ".......KFK",
        "........KK",
    ]),
    "T4": ("Ruban", [             # two translucent veils diverging
        "",
        "",
        "..........FF",
        "........FFFF",
        "......FFFF",
        "..KFFFFF",
        ".KFFF",
        "..KFFFFF",
        "......FFFF",
        "........FFFF",
        "..........FF",
    ]),
}

AXES = {"body": BODIES, "eye": EYES, "crest": CRESTS, "tail": TAILS}

# Colourways: the body ramp (Y body, O belly, H highlight, F fins, D
# dark shade) swapped as a set. The page recolours the layers in the
# browser; generate.py will take the same table.
PALETTES = {
    "or":      ("Or",      {"Y": "#F2C94C", "O": "#D99A2B", "H": "#FAE282", "F": "#F7E08A", "D": "#C48022"}),
    "corail":  ("Corail",  {"Y": "#F08A5D", "O": "#C95C3A", "H": "#FFB48F", "F": "#FFC9A8", "D": "#A64A2C"}),
    "lagon":   ("Lagon",   {"Y": "#4CC9C0", "O": "#2A9D96", "H": "#9CEDE7", "F": "#B8F2EC", "D": "#1F7A75"}),
    "lavande": ("Lavande", {"Y": "#A78BFA", "O": "#7C5CD6", "H": "#D1C4FF", "F": "#DCD3FF", "D": "#5F45B0"}),
    "menthe":  ("Menthe",  {"Y": "#7ED957", "O": "#4FA83A", "H": "#C0F2A6", "F": "#D2F5C0", "D": "#3B8228"}),
    "perle":   ("Perle",   {"Y": "#ECE7DC", "O": "#BFB6A6", "H": "#FFFFFF", "F": "#F6F2EA", "D": "#9A9082"}),
    "braise":  ("Braise",  {"Y": "#FF6B6B", "O": "#D64545", "H": "#FFB3B3", "F": "#FFC6C6", "D": "#A83232"}),
    "encre":   ("Encre",   {"Y": "#5C8DFF", "O": "#3A64C8", "H": "#A9C4FF", "F": "#BFD2FF", "D": "#2B4A99"}),
}
DEFAULT = {"body": "B1", "eye": "E1", "crest": "M1", "tail": "T1"}
DEFAULT_PALETTE = "or"


def blank():
    return ["." * BW for _ in range(BH)]


def place(rows, part, ax, ay):
    rows = [list(r) for r in rows]
    for y, line in enumerate(part):
        for x, c in enumerate(line):
            if c != "." and 0 <= ay + y < BH and 0 <= ax + x < BW:
                rows[ay + y][ax + x] = c
    return ["".join(r) for r in rows]


def anchors(config):
    return BODIES[config["body"]][2]


def compose(config, only=None, crest=True, crest_dy=0):
    """Stack tail, body, crest, eye on the body's anchors. `only` renders
    a single layer (for the configurator); crest=False leaves the crown
    bare (headphones); crest_dy lifts the crest (listening perk)."""
    body = BODIES[config["body"]][1]
    anc = anchors(config)
    rows = blank()
    for name in ("tail", "body", "crest", "eye"):
        if only and name != only:
            continue
        if name == "body":
            rows = place(rows, body, 0, 0)
        elif name == "crest":
            if crest:
                x, y = anc["crest"]
                rows = place(rows, CRESTS[config["crest"]][1], x, y + crest_dy)
        else:
            lib = TAILS if name == "tail" else EYES
            rows = place(rows, lib[config[name]][1], *anc[name])
    return rows


def main():
    os.makedirs(OUT, exist_ok=True)
    def save(name, rows):
        img = variants.compose(rows)
        generate.write_png(os.path.join(OUT, f"{name}.png"), variants.CW, variants.CH, img.get)
    for axis, lib in AXES.items():
        for key in lib:
            save(f"{axis}-{key}", compose(dict(DEFAULT, **{axis: key})))
    # transparent layers for the configurator: parts sit at a body's
    # anchors, so each body gets its own set
    for bkey in BODIES:
        base = dict(DEFAULT, body=bkey)
        save(f"layer-{bkey}-body", compose(base, only="body"))
        for axis in ("eye", "crest", "tail"):
            for key in AXES[axis]:
                save(f"layer-{bkey}-{axis}-{key}", compose(dict(base, **{axis: key}), only=axis))
    print("parts:", ", ".join(f"{a}×{len(l)}" for a, l in AXES.items()))


if __name__ == "__main__":
    main()
