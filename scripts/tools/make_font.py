#!/usr/bin/env python3
"""Draw Awash's compact pixel font as a Godot image-font sheet.

Each glyph is three pixels wide and five tall, in a four-by-six cell, so letters
keep a pixel apart and lines a pixel between them. The sheet holds printable
ASCII (0x20-0x7E) in 16 columns and 6 rows, the layout the font_data_image
importer reads; lowercase draws as capitals, as in the 5x7 font. Tune a glyph
here and rerun rather than editing the PNG.

Example:
  python scripts/tools/make_font.py --out assets/fonts/awash_pixel_3x5.png
"""

from __future__ import annotations

import argparse
import struct
import zlib
from pathlib import Path
from typing import Dict, List

CELL_WIDTH = 4
CELL_HEIGHT = 6
COLUMNS = 16
ROWS = 6
FIRST = 0x20
LAST = 0x7E

# Rows top to bottom; '#' is lit.
GLYPHS: Dict[str, List[str]] = {
    " ": ["...", "...", "...", "...", "..."],
    "!": [".#.", ".#.", ".#.", "...", ".#."],
    '"': ["#.#", "#.#", "...", "...", "..."],
    "#": ["#.#", "###", "#.#", "###", "#.#"],
    "$": [".##", "##.", ".#.", ".##", "##."],
    "%": ["#..", "..#", ".#.", "#..", "..#"],
    "&": [".#.", "#.#", ".#.", "#.#", ".##"],
    "'": [".#.", ".#.", "...", "...", "..."],
    "(": ["..#", ".#.", ".#.", ".#.", "..#"],
    ")": ["#..", ".#.", ".#.", ".#.", "#.."],
    "*": ["...", "#.#", ".#.", "#.#", "..."],
    "+": ["...", ".#.", "###", ".#.", "..."],
    ",": ["...", "...", "...", ".#.", "#.."],
    "-": ["...", "...", "###", "...", "..."],
    ".": ["...", "...", "...", "...", ".#."],
    "/": ["..#", "..#", ".#.", "#..", "#.."],
    "0": ["###", "#.#", "#.#", "#.#", "###"],
    "1": [".#.", "##.", ".#.", ".#.", "###"],
    "2": ["##.", "..#", ".#.", "#..", "###"],
    "3": ["##.", "..#", ".#.", "..#", "##."],
    "4": ["#.#", "#.#", "###", "..#", "..#"],
    "5": ["###", "#..", "##.", "..#", "##."],
    "6": [".##", "#..", "###", "#.#", "###"],
    "7": ["###", "..#", ".#.", ".#.", ".#."],
    "8": ["###", "#.#", "###", "#.#", "###"],
    "9": ["###", "#.#", "###", "..#", "##."],
    ":": ["...", ".#.", "...", ".#.", "..."],
    ";": ["...", ".#.", "...", ".#.", "#.."],
    "<": ["..#", ".#.", "#..", ".#.", "..#"],
    "=": ["...", "###", "...", "###", "..."],
    ">": ["#..", ".#.", "..#", ".#.", "#.."],
    "?": ["##.", "..#", ".#.", "...", ".#."],
    "@": [".#.", "#.#", "###", "#..", ".##"],
    "A": [".#.", "#.#", "###", "#.#", "#.#"],
    "B": ["##.", "#.#", "##.", "#.#", "##."],
    "C": [".##", "#..", "#..", "#..", ".##"],
    "D": ["##.", "#.#", "#.#", "#.#", "##."],
    "E": ["###", "#..", "##.", "#..", "###"],
    "F": ["###", "#..", "##.", "#..", "#.."],
    "G": [".##", "#..", "#.#", "#.#", ".##"],
    "H": ["#.#", "#.#", "###", "#.#", "#.#"],
    "I": ["###", ".#.", ".#.", ".#.", "###"],
    "J": ["..#", "..#", "..#", "#.#", ".#."],
    "K": ["#.#", "#.#", "##.", "#.#", "#.#"],
    "L": ["#..", "#..", "#..", "#..", "###"],
    "M": ["#.#", "###", "###", "#.#", "#.#"],
    "N": ["##.", "#.#", "#.#", "#.#", "#.#"],
    "O": [".#.", "#.#", "#.#", "#.#", ".#."],
    "P": ["##.", "#.#", "##.", "#..", "#.."],
    "Q": [".#.", "#.#", "#.#", "##.", ".##"],
    "R": ["##.", "#.#", "##.", "#.#", "#.#"],
    "S": [".##", "#..", ".#.", "..#", "##."],
    "T": ["###", ".#.", ".#.", ".#.", ".#."],
    "U": ["#.#", "#.#", "#.#", "#.#", "###"],
    "V": ["#.#", "#.#", "#.#", "#.#", ".#."],
    "W": ["#.#", "#.#", "###", "###", "#.#"],
    "X": ["#.#", "#.#", ".#.", "#.#", "#.#"],
    "Y": ["#.#", "#.#", ".#.", ".#.", ".#."],
    "Z": ["###", "..#", ".#.", "#..", "###"],
    "[": ["##.", "#..", "#..", "#..", "##."],
    "\\": ["#..", "#..", ".#.", "..#", "..#"],
    "]": [".##", "..#", "..#", "..#", ".##"],
    "^": [".#.", "#.#", "...", "...", "..."],
    "_": ["...", "...", "...", "...", "###"],
    "`": ["#..", ".#.", "...", "...", "..."],
    "{": [".##", ".#.", "##.", ".#.", ".##"],
    "|": [".#.", ".#.", ".#.", ".#.", ".#."],
    "}": ["##.", ".#.", ".##", ".#.", "##."],
    "~": ["...", ".##", "##.", "...", "..."],
}


def glyph_for(char: str) -> List[str]:
    return GLYPHS[char.upper()] if char.isalpha() else GLYPHS[char]


def sheet() -> List[List[bool]]:
    width, height = COLUMNS * CELL_WIDTH, ROWS * CELL_HEIGHT
    lit = [[False] * width for _ in range(height)]
    for code in range(FIRST, LAST + 1):
        index = code - FIRST
        left = (index % COLUMNS) * CELL_WIDTH
        top = (index // COLUMNS) * CELL_HEIGHT
        for y, row in enumerate(glyph_for(chr(code))):
            for x, pixel in enumerate(row):
                lit[top + y][left + x] = pixel == "#"
    return lit


def write_png(path: Path, lit: List[List[bool]]) -> None:
    """White glyphs on transparent, as 8-bit RGBA."""
    height, width = len(lit), len(lit[0])
    raw = b"".join(
        b"\x00" + b"".join(b"\xff\xff\xff\xff" if on else b"\x00\x00\x00\x00" for on in row)
        for row in lit
    )

    def chunk(kind: bytes, data: bytes) -> bytes:
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))

    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header)
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=Path("assets/fonts/awash_pixel_3x5.png"))
    args = parser.parse_args()
    missing = [chr(c) for c in range(FIRST, LAST + 1) if not chr(c).isalpha() or chr(c).isupper()]
    missing = [c for c in missing if c not in GLYPHS]
    if missing:
        raise SystemExit("No glyph for: " + "".join(missing))
    bad = [c for c, rows in GLYPHS.items() if len(rows) != 5 or any(len(r) != 3 for r in rows)]
    if bad:
        raise SystemExit("Not 3x5: " + "".join(bad))
    write_png(args.out, sheet())
    print(f"wrote {args.out}")


if __name__ == "__main__":
    main()
