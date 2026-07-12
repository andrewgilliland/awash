#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
	echo "Test run failed: '$GODOT_BIN' was not found in PATH."
	echo "Install Godot 4 and/or set GODOT_BIN to the executable path."
	exit 1
fi

echo "Running headless tests..."
"$GODOT_BIN" --headless --path "$PROJECT_ROOT" --script res://tests/test_runner.gd

echo "Test pass complete."
