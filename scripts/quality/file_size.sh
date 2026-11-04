#!/usr/bin/env bash
set -euo pipefail

# Rejects a commit that stages a hand-written file over 5,000 tokens, counting a token as 4 bytes.
# Only what is staged is weighed, as it is staged. Lockfiles, what Godot and the project's tools
# write (scenes, resources, imports, uids) and binary files are passed over: no one splits those.

MAX_TOKENS=5000
BYTES_PER_TOKEN=4
MAX_BYTES=$((MAX_TOKENS * BYTES_PER_TOKEN))

# Files nobody writes by hand, by glob on the path: lockfiles, then what Godot and the tools write.
IGNORED=(
	"*package-lock.json"
	"*npm-shrinkwrap.json"
	"*yarn.lock"
	"*pnpm-lock.yaml"
	"*.lock"
	"*.tscn"
	"*.tres"
	"*.import"
	"*.uid"
)

ignored() {
	local pattern
	for pattern in "${IGNORED[@]}"; do
		# shellcheck disable=SC2053
		[[ "$1" == $pattern ]] && return 0
	done
	return 1
}

# Git counts no lines for a binary file: its numstat is "-	-	path".
binary() {
	[[ "$(git diff --cached --numstat -- "$1")" == -$'\t'-$'\t'* ]]
}

# How to split a file, for its kind.
advice() {
	case "$1" in
	*.gd)
		echo "    GDScript: move a group of tests or functions into a new script beside it, a RefCounted"
		echo "    class with get_tests() or get_playtests() as tests/warden_playtests.gd has, and"
		echo "    preload(\"res://<path>\") it from the original, which runs what it returns."
		;;
	*.ts | *.tsx | *.js | *.mjs)
		echo "    TypeScript: move a group of functions into a new module beside it and"
		echo "    import { ... } from \"./<module>\" in the original; callers keep importing from where"
		echo "    they did, or follow the move."
		;;
	*.md)
		echo "    Markdown: split it by heading into files in a folder named for it, and leave the"
		echo "    original as a short index that links each part."
		;;
	*)
		echo "    Move a group of its functions or sections into a new file beside it, and have the"
		echo "    original load or link the new one."
		;;
	esac
}

too_big=()
while IFS= read -r -d '' path; do
	if ignored "$path" || binary "$path"; then
		continue
	fi
	bytes=$(git cat-file -s ":$path")
	if ((bytes > MAX_BYTES)); then
		too_big+=("$path"$'\t'"$bytes")
	fi
done < <(git diff --cached --name-only --diff-filter=ACMR -z)

if ((${#too_big[@]} == 0)); then
	exit 0
fi

echo "[pre-commit] Staged files over ${MAX_TOKENS} tokens (bytes / ${BYTES_PER_TOKEN}):"
for entry in "${too_big[@]}"; do
	path="${entry%%$'\t'*}"
	bytes="${entry##*$'\t'}"
	tokens=$(((bytes + BYTES_PER_TOKEN - 1) / BYTES_PER_TOKEN))
	echo "  ${path}: ${tokens} tokens (${bytes} bytes), over by $((tokens - MAX_TOKENS))"
done
echo
echo "Split each file into parts of at most ${MAX_TOKENS} tokens (${MAX_BYTES} bytes) before committing:"
echo "  1. Find its seams: group what is in it by the one thing each part is about (a feature, a"
echo "     Room, a kind of check, a section of a doc). Every group should stand on its own."
echo "  2. Move each group into a new file beside the original, named for that one thing."
echo "  3. Keep in the original only what ties the parts together, and have it load or link them."
echo "  4. Keep shared constants and helpers in one place every part uses, never copied."
echo "  5. Update everything that pointed into the moved parts: test runners, imports, links, docs."
echo "  6. Run ./scripts/quality/test.sh, then git add the new files and commit again."
for entry in "${too_big[@]}"; do
	path="${entry%%$'\t'*}"
	echo
	echo "  ${path}:"
	advice "$path"
done
echo
echo "If a file is generated, not written by hand or by an agent, add its glob to IGNORED in"
echo "scripts/quality/file_size.sh instead of splitting it."
exit 1
