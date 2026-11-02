#!/usr/bin/env bash
set -euo pipefail

# Draws the whole World as one PNG: ./scripts/tools/draw_world.sh [out.png]
# It opens a Godot window for a moment; a headless Godot draws nothing.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
OUT="${1:-${TMPDIR:-/tmp}/awash_world.png}"
case "$OUT" in
/*) ;;
*) OUT="$PWD/$OUT" ;;
esac

"$GODOT_BIN" --path "$PROJECT_ROOT" --script res://scripts/tools/draw_world.gd -- "$OUT"
