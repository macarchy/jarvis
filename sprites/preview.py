#!/usr/bin/env python3
"""preview — see a sprite sheet the way the artist needs to: pixel-exact.

Two views of any sheet written by generate.py (or variants.py):
  * ASCII: every composed frame rendered back to palette characters —
    lossless, greppable, the only view where a stray pixel cannot hide;
  * a magnified PNG (nearest-neighbor) of all frames, for the eye.

Usage: preview.py [--fw N] [--scale N] [--out FILE] [--no-ascii] sheet.png…
  --fw     frame width in sheet pixels (default: generate.W, or the sheet
           width when it is a single frame)
  --scale  magnification of the PNG (default 8)
  --out    PNG path (default: <first sheet>.preview.png next to the sheet)
"""

import os
import struct
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
import generate  # noqa: E402  (importable: rendering is behind __main__)

# First palette name wins for shared colors (K over P: the outline).
REVERSE = {}
for _k, _v in generate.PALETTE.items():
    if _v[3] > 0 and _v not in REVERSE:
        REVERSE[_v] = _k


def read_png(path):
    """Decode the PNGs generate.write_png produces (RGBA8, filter 0)."""
    data = open(path, "rb").read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", path
    pos, idat, w, h = 8, b"", 0, 0
    while pos < len(data):
        ln = struct.unpack(">I", data[pos:pos + 4])[0]
        tag, body = data[pos + 4:pos + 8], data[pos + 8:pos + 8 + ln]
        pos += 12 + ln
        if tag == b"IHDR":
            w, h, depth, ctype = struct.unpack(">IIBB", body[:10])
            assert (depth, ctype) == (8, 6), "expected RGBA8"
        elif tag == b"IDAT":
            idat += body
    raw = zlib.decompress(idat)
    stride = w * 4 + 1
    rows = []
    for y in range(h):
        line = raw[y * stride:(y + 1) * stride]
        assert line[0] == 0, "only filter 0 is supported (our own writer)"
        rows.append([tuple(line[1 + x * 4:5 + x * 4]) for x in range(w)])
    return w, h, rows


def char_for(rgba):
    if rgba[3] == 0:
        return "."
    if rgba in REVERSE:
        return REVERSE[rgba]
    best, dist = "?", 1e9
    for color, ch in REVERSE.items():
        d = sum((a - b) ** 2 for a, b in zip(color[:3], rgba[:3])) + (color[3] - rgba[3]) ** 2
        if d < dist:
            best, dist = ch, d
    return best


def ascii_frames(rows, fw):
    h, w = len(rows), len(rows[0])
    n = max(1, w // fw)
    out = []
    for i in range(n):
        out.append(["".join(char_for(px) for px in row[i * fw:(i + 1) * fw]) for row in rows])
    return out


def main(argv):
    fw, scale, out, ascii_on, sheets = None, 8, None, True, []
    it = iter(argv)
    for a in it:
        if a == "--fw":
            fw = int(next(it))
        elif a == "--scale":
            scale = int(next(it))
        elif a == "--out":
            out = next(it)
        elif a == "--no-ascii":
            ascii_on = False
        else:
            sheets.append(a)
    if not sheets:
        print(__doc__)
        return 1
    decoded = [(p, *read_png(p)) for p in sheets]
    if ascii_on:
        for path, w, h, rows in decoded:
            frames = ascii_frames(rows, fw or (generate.W if w % generate.W == 0 and w > generate.W else w))
            print(f"== {os.path.basename(path)}  {w}x{h}  {len(frames)} frame(s)")
            for y in range(h):
                print("   ".join(f[y] for f in frames))
            print()
    gap = 2
    total_h = sum(h for _, _, h, _ in decoded) + gap * (len(decoded) - 1)
    max_w = max(w for _, w, _, _ in decoded)
    canvas = {}
    y0 = 0
    for _, w, h, rows in decoded:
        for y in range(h):
            for x in range(w):
                if rows[y][x][3]:
                    canvas[(x, y0 + y)] = rows[y][x]
        y0 += h + gap
    bg = (32, 48, 63, 255)

    def px(x, y):
        return canvas.get((x // scale, y // scale), bg)

    out = out or (sheets[0] + ".preview.png")
    generate.write_png(out, max_w * scale, total_h * scale, px)
    print(f"png: {out} ({max_w * scale}x{total_h * scale})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
