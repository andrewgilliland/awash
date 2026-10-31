#!/usr/bin/env python3
"""Draw placeholder sheets for the Reefback, to be drawn over in Aseprite.

The Reefback sheet is one row of eight 48x48 frames facing right:
  roar, stand, walk, walk, walk, swipe, overhead, jump
The props sheet is four 16x16 frames: a reef chunk spinning (two), the chunk shattered, a rock.

Both are plain on purpose: flat slate-grey shapes ringed in black, a few coral bumps on the back,
and a pale face to show which way it faces. Draw the real Reefback over these frames, keeping
the layout, and the game picks it up; its Ward is drawn by a shader round whatever is there.

Example:
  python3 scripts/tools/make_reefback_placeholder.py
"""

from __future__ import annotations

import argparse
import math
import struct
import zlib
from pathlib import Path
from typing import Iterable, List, Optional, Tuple

FRAME = 48
PROP = 16
Colour = Tuple[int, int, int, int]
Cell = Tuple[int, int]

BLACK: Colour = (0, 0, 0, 255)
FUR: Colour = (70, 78, 96, 255)
FAR: Colour = (50, 56, 72, 255)
FACE: Colour = (150, 156, 168, 255)
CORAL: Colour = (214, 98, 108, 255)
REEF: Colour = (74, 160, 146, 255)
ROCK: Colour = (110, 104, 112, 255)


class Canvas:
    def __init__(self, size: int) -> None:
        self.size = size
        self.px: List[List[Optional[Colour]]] = [[None] * size for _ in range(size)]

    def put(self, x: int, y: int, colour: Colour) -> None:
        if 0 <= x < self.size and 0 <= y < self.size:
            self.px[y][x] = colour

    def part(self, cells: Iterable[Cell], colour: Colour, outline: bool = True) -> None:
        """Rings the cells in black over what is there, then fills them."""
        filled = set(cells)
        if outline:
            for (x, y) in filled:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    if (x + dx, y + dy) not in filled:
                        self.put(x + dx, y + dy, BLACK)
        for (x, y) in filled:
            self.put(x, y, colour)


def ellipse(cx: int, cy: int, rx: int, ry: int) -> List[Cell]:
    return [
        (x, y)
        for y in range(cy - ry, cy + ry + 1)
        for x in range(cx - rx, cx + rx + 1)
        if ((x - cx) / (rx + 0.5)) ** 2 + ((y - cy) / (ry + 0.5)) ** 2 <= 1.0
    ]


def limb(points: List[Cell], r: int) -> List[Cell]:
    """Every cell within r of the path through the points."""
    cells = []
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        dx, dy = x1 - x0, y1 - y0
        length = max(1e-6, dx * dx + dy * dy)
        for y in range(min(y0, y1) - r, max(y0, y1) + r + 1):
            for x in range(min(x0, x1) - r, max(x0, x1) + r + 1):
                t = max(0.0, min(1.0, ((x - x0) * dx + (y - y0) * dy) / length))
                if math.hypot(x - (x0 + t * dx), y - (y0 + t * dy)) <= r + 0.3:
                    cells.append((x, y))
    return cells


# Each frame: the body's centre and half-size, the head's centre, the far and near arms and legs
# as paths from shoulder or hip to hand or foot.
LEGS = ([(17, 34), (14, 40), (17, 46)], [(24, 34), (22, 40), (26, 46)])
FRAMES = [
    # roar: reared up, arms wide
    dict(body=(22, 24, 10, 12), head=(29, 10), far_arm=[(18, 16), (12, 10), (9, 4)],
         near_arm=[(27, 16), (34, 10), (38, 5)], legs=LEGS, open_mouth=True),
    # stand: hunched on its knuckles
    dict(body=(22, 27, 13, 10), head=(35, 24), far_arm=[(28, 22), (31, 34), (31, 45)],
         near_arm=[(33, 23), (38, 34), (39, 45)], legs=LEGS),
    # walk
    dict(body=(22, 27, 13, 10), head=(36, 24), far_arm=[(28, 22), (29, 34), (27, 45)],
         near_arm=[(33, 23), (40, 33), (43, 44)],
         legs=([(17, 34), (13, 40), (19, 46)], [(24, 34), (17, 41), (15, 46)])),
    dict(body=(22, 26, 13, 10), head=(35, 23), far_arm=[(28, 21), (31, 33), (33, 44)],
         near_arm=[(33, 22), (37, 33), (37, 45)], legs=LEGS),
    dict(body=(22, 27, 13, 10), head=(36, 24), far_arm=[(28, 22), (33, 33), (36, 45)],
         near_arm=[(33, 23), (36, 34), (34, 45)],
         legs=([(17, 34), (11, 40), (12, 46)], [(24, 34), (20, 41), (26, 46)])),
    # swipe: lunging, near arm swept low and forward
    dict(body=(23, 29, 13, 10), head=(37, 26), far_arm=[(28, 24), (32, 35), (31, 45)],
         near_arm=[(34, 25), (41, 33), (46, 40)],
         legs=([(17, 36), (11, 41), (13, 46)], [(24, 36), (20, 42), (25, 46)])),
    # overhead: reared up, both arms high
    dict(body=(22, 24, 10, 12), head=(29, 10), far_arm=[(18, 16), (18, 8), (23, 2)],
         near_arm=[(27, 16), (30, 8), (34, 2)], legs=LEGS, open_mouth=True),
    # jump: tucked in the air, arms raised
    dict(body=(24, 22, 12, 10), head=(36, 18), far_arm=[(29, 17), (32, 9), (36, 4)],
         near_arm=[(33, 18), (39, 11), (44, 7)],
         legs=([(18, 28), (14, 34), (20, 38)], [(24, 28), (21, 35), (27, 38)])),
]


def reefback_frame(spec: dict) -> Canvas:
    c = Canvas(FRAME)
    bx, by, rx, ry = spec["body"]
    hx, hy = spec["head"]
    far_leg, near_leg = spec["legs"]
    c.part(limb(far_leg, 3), FAR)
    c.part(limb(spec["far_arm"], 3), FAR)
    c.part(ellipse(bx, by, rx, ry), FUR)
    c.part(limb(near_leg, 3), FUR)
    # A few coral bumps along the top of its back.
    for i, dx in enumerate((-8, -3, 2)):
        c.part(ellipse(bx + dx, by - ry + 1, 2, 2), CORAL if i % 2 == 0 else REEF)
    # Head, with a pale face to show which way it looks.
    c.part(ellipse(hx, hy, 6, 6), FUR)
    c.part(ellipse(hx + 2, hy + 1, 3, 3), FACE)
    if spec.get("open_mouth"):
        c.part([(hx + 2, hy + 3), (hx + 3, hy + 3), (hx + 4, hy + 3)], BLACK, outline=False)
    c.part(limb(spec["near_arm"], 3), FUR)
    return c


def prop_frames() -> List[Canvas]:
    frames = []
    for spin in range(2):
        c = Canvas(PROP)
        c.part(ellipse(8, 8, 5 - spin, 3 + spin), CORAL)
        c.part(ellipse(9 - spin, 7 + spin, 1, 1), REEF, outline=False)
        frames.append(c)
    shattered = Canvas(PROP)
    for (x, y, r) in ((4, 11, 1), (11, 10, 2), (8, 13, 1), (7, 7, 1), (13, 13, 1)):
        shattered.part(ellipse(x, y, r, r), CORAL if (x + y) % 2 else REEF)
    frames.append(shattered)
    rock = Canvas(PROP)
    rock.part(ellipse(8, 8, 4, 3), ROCK)
    frames.append(rock)
    return frames


def write_png(path: Path, frames: List[Canvas], size: int) -> None:
    width = size * len(frames)
    rows = []
    for y in range(size):
        row = bytearray(b"\x00")
        for frame in frames:
            for x in range(size):
                row += bytes(frame.px[y][x] or (0, 0, 0, 0))
        rows.append(bytes(row))

    def chunk(kind: bytes, data: bytes) -> bytes:
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))

    header = struct.pack(">IIBBBBB", width, size, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header)
    png += chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) + chunk(b"IEND", b"")
    path.write_bytes(png)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=Path("assets/sprites/enemies"))
    args = parser.parse_args()
    write_png(args.out / "reefback_1.png", [reefback_frame(f) for f in FRAMES], FRAME)
    write_png(args.out / "reefback_props.png", prop_frames(), PROP)
    print("reefback_1.png  reefback_props.png")


if __name__ == "__main__":
    main()
