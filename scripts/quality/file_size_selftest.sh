#!/usr/bin/env bash
set -euo pipefail

# Proves the file size gate judges only what is staged, by what is staged: it passes small files
# and generated or binary ones however big, and rejects a hand-written file over the limit, saying
# how to split it. The fixture is a throwaway git repo, so nothing big is ever committed here.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
failures=0
# Just over the limit: 5,000 tokens at 4 bytes a token is 20,000 bytes.
BIG=20004

fresh_repo() {
	rm -rf "${fixture:?}"
	mkdir -p "$fixture"
	git -C "$fixture" init -q
	git -C "$fixture" config user.email "selftest@example.com"
	git -C "$fixture" config user.name "Selftest"
}

# write <path> <bytes>: a text file of that many bytes.
write() {
	mkdir -p "$fixture/$(dirname "$1")"
	head -c "$2" /dev/zero | tr '\0' 'a' >"$fixture/$1"
}

# expect <pass|fail> <label> [text the output must hold]...: runs the gate in the fixture.
expect() {
	local want="$1" label="$2" got="pass"
	shift 2
	if ! (cd "$fixture" && "$SCRIPT_DIR/file_size.sh") >"$fixture.log" 2>&1; then
		got="fail"
	fi
	local missing=""
	for text in "$@"; do
		grep -qF -- "$text" "$fixture.log" || missing="$missing [$text]"
	done
	if [[ "$got" == "$want" && -z "$missing" ]]; then
		echo "PASS: file size gate should ${want} on ${label}"
	else
		echo "FAIL: file size gate should ${want} on ${label}, but it ${got}ed${missing:+; missing$missing}"
		sed 's/^/    /' "$fixture.log"
		failures=$((failures + 1))
	fi
}

fresh_repo
write scripts/small.gd 400
git -C "$fixture" add scripts/small.gd
expect pass "a small staged file"

fresh_repo
write scripts/exact.gd 20000
git -C "$fixture" add scripts/exact.gd
expect pass "a file of exactly 5,000 tokens"

fresh_repo
write tests/huge_runner.gd "$BIG"
git -C "$fixture" add tests/huge_runner.gd
expect fail "a hand-written script over 5,000 tokens" \
	"tests/huge_runner.gd" "5001 tokens" "20004 bytes" "Split" "preload("

fresh_repo
write docs/guide.md "$BIG"
write src/view.ts "$BIG"
git -C "$fixture" add docs/guide.md src/view.ts
expect fail "a doc and a module over 5,000 tokens, each named with its own advice" \
	"docs/guide.md" "src/view.ts" "heading" "import"

fresh_repo
write src/huge.ts "$BIG"
expect pass "a big file that is not staged"

fresh_repo
write src/shrunk.ts "$BIG"
git -C "$fixture" add src/shrunk.ts
write src/shrunk.ts 100
expect fail "a big staged file shrunk only in the working tree" "src/shrunk.ts"

fresh_repo
write tools/editor/package-lock.json "$BIG"
write Cargo.lock "$BIG"
write pnpm-lock.yaml "$BIG"
write yarn.lock "$BIG"
git -C "$fixture" add -A
expect pass "big lockfiles"

fresh_repo
write scenes/regions/background.tscn "$BIG"
write assets/tiles/scenery.tres "$BIG"
write assets/art/sheet.png.import "$BIG"
write scripts/main.gd.uid "$BIG"
git -C "$fixture" add -A
expect pass "big files Godot or the tools write: scenes, resources, imports and uids"

fresh_repo
mkdir -p "$fixture/assets"
head -c "$BIG" /dev/urandom >"$fixture/assets/sheet.png"
git -C "$fixture" add assets/sheet.png
expect pass "a big binary file"

fresh_repo
write scripts/small.gd 400
git -C "$fixture" add scripts/small.gd
git -C "$fixture" commit -qm "small" --no-verify
git -C "$fixture" rm -q scripts/small.gd
expect pass "a deleted file"

if ((failures > 0)); then
	echo "${failures} file size selftest(s) failed"
	exit 1
fi
echo "All file size selftests passed"
