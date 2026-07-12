# Pre-commit Hook

Awash uses a repository-managed git pre-commit hook to run all quality gates.

## What Runs
1. Typecheck
2. Lint/format check
3. Tests

## Install
From the project root:

```bash
./scripts/install_hooks.sh
```

## Notes
- The hook is in `.githooks/pre-commit`.
- The install command sets `core.hooksPath` to `.githooks` for this local clone.
- You can still run gates manually from `scripts/quality`.
