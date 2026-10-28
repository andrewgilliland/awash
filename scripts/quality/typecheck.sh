#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# TYPECHECK_ROOT points the gate at another project; typecheck_selftest.sh uses it for fixtures.
PROJECT_ROOT="${TYPECHECK_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
GODOT_BIN="${GODOT_BIN:-godot}"
# shellcheck source=godot_timeout.sh
source "$SCRIPT_DIR/godot_timeout.sh"

if [[ "$GODOT_BIN" == */* ]]; then
	if [[ ! -x "$GODOT_BIN" ]]; then
		echo "Typecheck failed: '$GODOT_BIN' is not executable."
		exit 1
	fi
elif ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
	echo "Typecheck failed: '$GODOT_BIN' was not found in PATH."
	echo "Install Godot 4 and/or set GODOT_BIN to the executable path."
	exit 1
fi

cd "$PROJECT_ROOT"
log="$(mktemp)"
trap 'rm -f "$log"' EXIT
failures=0

# Godot exits 0 from a plain boot even when a script fails to compile, so each script is checked
# on its own: --check-only exits non-zero on parse, type and missing-dependency errors.
echo "Checking every script for parse, type and dependency errors..."
while IFS= read -r script; do
	if ! run_godot --headless --path "$PROJECT_ROOT" --check-only --script "res://$script" \
		>"$log" 2>&1; then
		echo "Typecheck error in $script:"
		sed 's/^/    /' "$log"
		failures=$((failures + 1))
	fi
done < <(find scripts tests -name '*.gd' 2>/dev/null | sort)

# Booting the main scene catches errors that only appear once scripts run; Godot prints them but
# still exits 0, so the log decides.
echo "Booting the main scene..."
boot_status=0
run_godot --headless --path "$PROJECT_ROOT" --quit >"$log" 2>&1 || boot_status=$?
if ((boot_status != 0)) || grep -q "ERROR:" "$log"; then
	echo "Typecheck error while booting the main scene:"
	sed 's/^/    /' "$log"
	failures=$((failures + 1))
fi

if ((failures > 0)); then
	echo "Typecheck failed: $failures problem(s)."
	exit 1
fi
echo "Typecheck pass complete."
