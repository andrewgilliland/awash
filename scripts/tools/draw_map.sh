#!/usr/bin/env bash
set -euo pipefail

# Draws the whole World as the Map draws it, planned Rooms too: ./scripts/tools/draw_map.sh [out.png]
# It opens a Godot window for a moment; a headless Godot draws nothing.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
OUT="${1:-${TMPDIR:-/tmp}/awash_map.png}"
case "$OUT" in
/*) ;;
*) OUT="$PWD/$OUT" ;;
esac

"$GODOT_BIN" --path "$PROJECT_ROOT" --script res://scripts/tools/draw_map.gd -- "$OUT"
