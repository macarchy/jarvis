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

# ------------------------------------------------------------------ body
#
# C2's body alone: eye socket filled with flesh, no crest, right edge
# closed at the peduncle (cols 35-37) where every tail attaches.
BODY = variants.pad([
    "",
    "",
    "",
    "",
    "",
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
])

ANCHORS = {"eye": (4, 9), "crest": (7, 0), "tail": (35, 9)}

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
    "E4": ("Anneau", [           # no white: a ring, Game Boy style
        "",
        "....KKKK",
        "...KHHHHK",
        "..KHKKKKHK",
        "..KHKKKKHK",
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
        ".KYYYYYYYYYYYYYYKKKY",
    ]),
    "M2": ("Plumes", [            # three thick plumes with barbs
        "...BB......BB.....BB",
        "..KYYK....KYYK....KYYK",
        ".KFYYFK..KFYYFK..KFYYFK",
        "..KYYK....KYYK....KYYK",
        ".KFYYFK..KFYYFK..KFYYFK",
        "..KYYK....KYYK....KYYK",
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
    "T2": ("Éventail", [          # rounded fan, goldfish-like
        "",
        ".....KKKK",
        "...KKFFFFK",
        "..KFFFFFFFK",
        ".KKFFFFFFFFK",
        ".KFFFFFFFFFK",
        ".KFFFFFFFFFK",
        ".KFFFFFFFFFK",
        ".KKFFFFFFFFK",
        "..KFFFFFFFK",
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
    "T4": ("Ruban", [             # translucent double ribbon, no outline
        "",
        "",
        "........FF",
        "......FFFF",
        "..FFFFFFF",
        ".FFFFFFFFFF",
        ".FFFFFFFF",
        ".FFFFFFFFFF",
        "..FFFFFFF",
        "......FFFF",
        "........FF",
    ]),
}

AXES = {"eye": EYES, "crest": CRESTS, "tail": TAILS}
DEFAULT = {"eye": "E1", "crest": "M1", "tail": "T1"}


def blank():
    return ["." * BW for _ in range(BH)]


def place(rows, part, ax, ay):
    rows = [list(r) for r in rows]
    for y, line in enumerate(part):
        for x, c in enumerate(line):
            if c != "." and 0 <= ay + y < BH and 0 <= ax + x < BW:
                rows[ay + y][ax + x] = c
    return ["".join(r) for r in rows]


def compose(config, body=BODY, only=None):
    """Stack tail, body, crest, eye. `only` renders a single layer
    (for the configurator) on an otherwise empty box."""
    rows = blank()
    order = [("tail", TAILS), ("body", None), ("crest", CRESTS), ("eye", EYES)]
    for name, lib in order:
        if only and name != only:
            continue
        if name == "body":
            rows = place(rows, body, 0, 0)
        else:
            part = lib[config[name]][1]
            rows = place(rows, part, *ANCHORS[name])
    return rows


def main():
    os.makedirs(OUT, exist_ok=True)
    def save(name, rows):
        img = variants.compose(rows)
        generate.write_png(os.path.join(OUT, f"{name}.png"), variants.CW, variants.CH, img.get)
    # one PNG per axis variant, the other axes at their default
    for axis, lib in AXES.items():
        for key in lib:
            cfg = dict(DEFAULT, **{axis: key})
            save(f"{axis}-{key}", compose(cfg))
    # transparent layers for the configurator
    save("layer-body", compose(DEFAULT, only="body"))
    for axis, lib in AXES.items():
        for key in lib:
            save(f"layer-{axis}-{key}", compose(dict(DEFAULT, **{axis: key}), only=axis))
    print("parts:", ", ".join(f"{a}×{len(l)}" for a, l in AXES.items()))


if __name__ == "__main__":
    main()
