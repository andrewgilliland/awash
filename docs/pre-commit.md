# Pre-commit Hook

Awash uses repository-managed git hooks to run all quality gates and keep the branching
workflow in `AGENTS.md`.

## What Runs
Pre-commit:
1. Branch check: commits are allowed only on `feature/*` or `fix/*` branches.
2. Typecheck
3. Lint/format check
4. Tests

Pre-push:
1. Blocks direct pushes to `main` and `dev`; both change only through GitHub pull requests.

## Install
From the project root:

```bash
./scripts/install_hooks.sh
```

## Notes
- The hooks are in `.githooks/pre-commit` and `.githooks/pre-push`.
- The install command sets `core.hooksPath` to `.githooks` for this local clone.
- You can still run gates manually from `scripts/quality`.
- GitHub rulesets and the `branch-check` workflow enforce the branching rules on the server.
- The `quality` workflow (`.github/workflows/quality.yml`) runs typecheck, lint, tests and the
  playtest on every PR into `dev` or `main`, against the PR merged with its base. Rulesets on
  both branches require it, so a skipped hook (`--no-verify`) or a change made on GitHub is still
  checked before it merges.
