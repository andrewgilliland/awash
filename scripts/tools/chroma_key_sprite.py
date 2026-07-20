#!/usr/bin/env python3
"""Apply chroma key transparency to sprite sheets.

Examples:
  python scripts/tools/chroma_key_sprite.py \
    --input assets/sprites/alucard_sprite_sheet.png \
    --auto-key --tolerance 8 --in-place

  python scripts/tools/chroma_key_sprite.py \
    --input assets/sprites/alucard_sprite_sheet.png \
    --output assets/sprites/alucard_sprite_sheet.transparent.png \
    --key-color 104,120,136 --tolerance 8
"""

from __future__ import annotations

import argparse
from collections import Counter
from pathlib import Path
from typing import Sequence, Tuple

from PIL import Image


def parse_key_color(value: str) -> Tuple[int, int, int]:
    parts = value.split(",")
    if len(parts) != 3:
        raise argparse.ArgumentTypeError("key color must be R,G,B")

    try:
        rgb = tuple(int(part.strip()) for part in parts)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("key color must be integers") from exc

    for channel in rgb:
        if channel < 0 or channel > 255:
            raise argparse.ArgumentTypeError("each channel must be in range 0..255")

    return rgb  # type: ignore[return-value]


def infer_border_key_color(image: Image.Image) -> Tuple[int, int, int]:
    width, height = image.size
    pix = image.load()
    samples: list[Tuple[int, int, int]] = []

    for x in range(width):
        samples.append(pix[x, 0][:3])
        samples.append(pix[x, height - 1][:3])

    for y in range(height):
        samples.append(pix[0, y][:3])
        samples.append(pix[width - 1, y][:3])

    key_rgb, _ = Counter(samples).most_common(1)[0]
    return key_rgb


def apply_chroma_key(
    image: Image.Image, key_rgb: Tuple[int, int, int], tolerance: int
) -> Tuple[int, int, int]:
    pix = image.load()
    width, height = image.size

    changed = 0
    alpha_zero_before = 0
    alpha_zero_after = 0

    for y in range(height):
        for x in range(width):
            r, g, b, a = pix[x, y]
            if a == 0:
                alpha_zero_before += 1
                alpha_zero_after += 1
                continue

            if (
                abs(r - key_rgb[0]) <= tolerance
                and abs(g - key_rgb[1]) <= tolerance
                and abs(b - key_rgb[2]) <= tolerance
            ):
                pix[x, y] = (r, g, b, 0)
                changed += 1
                alpha_zero_after += 1

    return changed, alpha_zero_before, alpha_zero_after


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Apply chroma key transparency to sprite sheets")
    parser.add_argument("--input", required=True, help="Input PNG path")
    parser.add_argument(
        "--output",
        default="",
        help="Output PNG path (defaults to input path when --in-place is set)",
    )
    parser.add_argument(
        "--key-color",
        type=parse_key_color,
        default=(255, 255, 255),
        help="Chroma key color as R,G,B (default: 255,255,255)",
    )
    parser.add_argument(
        "--auto-key",
        action="store_true",
        help="Infer key color from most common border pixel",
    )
    parser.add_argument(
        "--tolerance",
        type=int,
        default=8,
        help="Per-channel tolerance 0..255 (default: 8)",
    )
    parser.add_argument(
        "--in-place",
        action="store_true",
        help="Overwrite input file",
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.tolerance < 0 or args.tolerance > 255:
        parser.error("--tolerance must be in range 0..255")

    input_path = Path(args.input)
    if not input_path.exists():
        parser.error(f"input file not found: {input_path}")

    if input_path.suffix.lower() != ".png":
        parser.error("input file must be a PNG")

    if args.in_place:
        output_path = input_path
    elif args.output:
        output_path = Path(args.output)
    else:
        parser.error("set either --in-place or --output")

    image = Image.open(input_path).convert("RGBA")
    key_rgb = infer_border_key_color(image) if args.auto_key else args.key_color

    changed, alpha_before, alpha_after = apply_chroma_key(image, key_rgb, args.tolerance)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    image.save(output_path)

    print(f"input={input_path}")
    print(f"output={output_path}")
    print(f"size={image.size[0]}x{image.size[1]}")
    print(f"key_rgb={key_rgb} tolerance={args.tolerance}")
    print(f"newly_transparent={changed}")
    print(f"alpha0_before={alpha_before} alpha0_after={alpha_after}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
