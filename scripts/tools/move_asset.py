#!/usr/bin/env python3
"""Move assets in the Godot project without breaking what refers to them.

Each move takes the asset with its .import file (`git mv`), points the import at the new source,
and rewrites every mention of the old path, with or without res://, in the repo's tracked text
files: scenes, resources, scripts, shaders, tests, docs and tools. Godot keeps each asset's uid,
so references by uid hold too. Run Godot's import afterwards to rebuild its cache.

Moves are pairs of repo paths, given on the command line or one `old -> new` per line in a file.

Example:
  python3 scripts/tools/move_asset.py assets/ui/old.png assets/ui/new.png
  python3 scripts/tools/move_asset.py --map moves.txt
"""

from __future__ import annotations

import argparse
import subprocess
from pathlib import Path
from typing import List, Tuple

# The kinds of tracked file that can mention an asset's path.
TEXT_KINDS = {".tscn", ".tres", ".gd", ".gdshader", ".godot", ".cfg", ".import", ".md", ".py", ".sh"}


def git(*args: str) -> str:
    return subprocess.run(["git", *args], check=True, capture_output=True, text=True).stdout


def read_map(path: Path) -> List[Tuple[str, str]]:
    moves = []
    for line in path.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            old, new = (part.strip() for part in line.split("->"))
            moves.append((old, new))
    return moves


def move(old: str, new: str) -> None:
    Path(new).parent.mkdir(parents=True, exist_ok=True)
    git("mv", old, new)
    if Path(old + ".import").exists():
        git("mv", old + ".import", new + ".import")


def rewrite(moves: List[Tuple[str, str]]) -> int:
    """Replaces each old path with its new one in every tracked text file; returns files changed."""
    changed = 0
    for name in git("ls-files").splitlines():
        path = Path(name)
        if path.suffix not in TEXT_KINDS or not path.exists():
            continue
        text = path.read_text()
        updated = text
        for old, new in moves:
            updated = updated.replace(old, new)
        if updated != text:
            path.write_text(updated)
            changed += 1
    return changed


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("paths", nargs="*", help="old new [old new ...]")
    parser.add_argument("--map", type=Path, help="a file of `old -> new` lines")
    args = parser.parse_args()
    moves = read_map(args.map) if args.map else []
    if len(args.paths) % 2:
        parser.error("give paths in old new pairs")
    moves += list(zip(args.paths[::2], args.paths[1::2]))
    for old, new in moves:
        move(old, new)
    # Longest first, so a path is never rewritten by a shorter one it starts with.
    moves.sort(key=lambda pair: len(pair[0]), reverse=True)
    print(f"moved {len(moves)} assets; rewrote {rewrite(moves)} files")


if __name__ == "__main__":
    main()
