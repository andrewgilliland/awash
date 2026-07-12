#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if ! command -v gdlint >/dev/null 2>&1; then
	echo "Lint failed: gdlint not found. Install dev dependencies first:"
	echo "python3 -m pip install -r requirements-dev.txt"
	exit 1
fi

if ! command -v gdformat >/dev/null 2>&1; then
	echo "Lint failed: gdformat not found. Install dev dependencies first:"
	echo "python3 -m pip install -r requirements-dev.txt"
	exit 1
fi

cd "$PROJECT_ROOT"
targets=(scripts)
if [[ -d tests ]]; then
	targets+=(tests)
fi

echo "Running gdlint..."
gdlint "${targets[@]}"
echo "Running gdformat check..."
gdformat --check "${targets[@]}"

echo "Lint pass complete."
