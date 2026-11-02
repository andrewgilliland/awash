#!/usr/bin/env bash
set -euo pipefail

# Draws the whole World as the Map draws it: ./scripts/tools/draw_map.sh [--plan] [out.png]
# With --plan it draws the World's plan, the Planned Rooms in outline.
# It opens a Godot window for a moment; a headless Godot draws nothing.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
PLAN=()
if [[ "${1:-}" == "--plan" ]]; then
	PLAN=(--plan)
	shift
fi
OUT="${1:-${TMPDIR:-/tmp}/awash_map.png}"
case "$OUT" in
/*) ;;
*) OUT="$PWD/$OUT" ;;
esac

"$GODOT_BIN" --path "$PROJECT_ROOT" --script res://scripts/tools/draw_map.gd -- ${PLAN[@]+"${PLAN[@]}"} "$OUT"
