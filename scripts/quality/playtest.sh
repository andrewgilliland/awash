#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
# shellcheck source=godot_timeout.sh
source "$PROJECT_ROOT/scripts/quality/godot_timeout.sh"

if [[ "$GODOT_BIN" == */* ]]; then
	if [[ ! -x "$GODOT_BIN" ]]; then
		echo "Playtest failed: '$GODOT_BIN' is not executable."
		exit 1
	fi
elif ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
	echo "Playtest failed: '$GODOT_BIN' was not found in PATH."
	echo "Install Godot 4 and/or set GODOT_BIN to the executable path."
	exit 1
fi

echo "Running deterministic headless playtests..."
run_godot --headless --path "$PROJECT_ROOT" --fixed-fps 60 --script res://tests/playtest_runner.gd

echo "Playtest pass complete."
