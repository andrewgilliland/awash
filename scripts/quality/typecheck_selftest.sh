#!/usr/bin/env bash
set -euo pipefail

# Proves the typecheck gate can fail: it must pass a clean fixture project and reject each broken
# one. The fixture lives in a temp dir, so no broken script is ever committed or linted.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
failures=0

write_clean_fixture() {
	rm -rf "${fixture:?}"/*
	mkdir -p "$fixture/scripts"
	cat >"$fixture/project.godot" <<'EOF'
config_version=5

[application]
config/name="Typecheck fixture"
run/main_scene="res://main.tscn"
EOF
	cat >"$fixture/main.tscn" <<'EOF'
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/main.gd" id="1"]

[node name="Main" type="Node"]
script = ExtResource("1")
EOF
	printf 'extends Node\n\n\nfunc _ready() -> void:\n\tpass\n' >"$fixture/scripts/main.gd"
}

# expect <pass|fail> <label>: runs the gate on the fixture as it stands.
expect() {
	local want="$1" label="$2" got="pass"
	if ! TYPECHECK_ROOT="$fixture" "$SCRIPT_DIR/typecheck.sh" >"$fixture.log" 2>&1; then
		got="fail"
	fi
	if [[ "$got" == "$want" ]]; then
		echo "PASS: typecheck should ${want} on ${label}"
	else
		echo "FAIL: typecheck should ${want} on ${label}, but it ${got}ed"
		sed 's/^/    /' "$fixture.log"
		failures=$((failures + 1))
	fi
}

write_clean_fixture
expect pass "a clean project"

write_clean_fixture
printf 'extends Node\n\n\nfunc broken( -> void:\n\tpass\n' >"$fixture/scripts/parse.gd"
expect fail "a parse error"

write_clean_fixture
printf 'extends Node\n\n\nfunc typed() -> void:\n\tvar n: int = "text"\n' >"$fixture/scripts/types.gd"
expect fail "a type error"

write_clean_fixture
printf 'extends Node\n\nconst Missing := preload("res://scripts/nope.gd")\n' >"$fixture/scripts/dep.gd"
expect fail "a missing preload"

write_clean_fixture
printf 'extends Node\n\n\nfunc _ready() -> void:\n\tvar n: Node = null\n\tn.queue_free()\n' \
	>"$fixture/scripts/main.gd"
expect fail "a script error while the main scene boots"

rm -f "$fixture.log"
if ((failures > 0)); then
	echo "Typecheck self-test failed: $failures case(s)."
	exit 1
fi
echo "Typecheck self-test passed."
