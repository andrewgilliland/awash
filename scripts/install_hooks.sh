#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$PROJECT_ROOT"

git config core.hooksPath .githooks
chmod +x .githooks/pre-commit

if [[ -f scripts/quality/typecheck.sh ]]; then
	chmod +x scripts/quality/typecheck.sh
fi
if [[ -f scripts/quality/lint.sh ]]; then
	chmod +x scripts/quality/lint.sh
fi
if [[ -f scripts/quality/test.sh ]]; then
	chmod +x scripts/quality/test.sh
fi

echo "Git hooks installed. Pre-commit will now run typecheck, lint, and tests."
