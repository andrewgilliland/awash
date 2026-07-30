---
name: godot-quality-gate
description: "Use when preparing code for commit, validating Godot changes, running quality gates, checking regressions, or deciding if playtest is required in this Awash repository."
---

# Godot Quality Gate

## Purpose

Provide a consistent, low-risk release-readiness workflow for this repository.

## Use When

- A code or scene change was made and needs verification.
- The user asks to "run checks", "validate", "review before commit", or "make sure this is safe".
- You need to decide whether a playtest is required.

## Repository Commands

Run commands from the repository root:

- `./scripts/quality/typecheck.sh`
- `./scripts/quality/lint.sh`
- `./scripts/quality/test.sh`
- `./scripts/quality/playtest.sh`

## Required Workflow

1. Identify change scope from modified files.
2. Run baseline gates in order:
   - `./scripts/quality/typecheck.sh`
   - `./scripts/quality/lint.sh`
   - `./scripts/quality/test.sh`
3. Decide if playtest is required.
4. If required, run `./scripts/quality/playtest.sh`.
5. Summarize pass/fail status and any actionable failures.

## Playtest Decision Rule

Run playtest when changes touch runtime behavior or flow-sensitive content, especially:

- `scenes/main.tscn`
- `scripts/core/main.gd`
- player movement/combat/state logic in `scripts/player/`
- pause/menu runtime flow in `scenes/ui/` or `scripts/ui/`
- camera, spawning, or world resolution logic

If unsure, run playtest.

## Failure Handling

- Stop at first failing gate only when the failure clearly blocks later signals.
- Otherwise, continue through baseline gates to return a fuller failure report.
- Report concise, file-specific fixes first.
- Re-run only affected gate(s) plus downstream gates after fixes.

## Commit Hygiene Checklist

Before proposing commit:

- Stage only files related to the user request.
- Avoid unrelated scene/editor churn.
- Keep commit message short and descriptive.

## Output Template

Return results in this structure:

1. Scope: files and risk level.
2. Gates:
   - typecheck: pass/fail
   - lint: pass/fail
   - test: pass/fail
   - playtest: pass/fail or skipped with reason
3. Findings: key failures with path and reason.
4. Recommendation: ready to commit or required follow-up.

## Notes

- Follow repository conventions in `AGENTS.md`.
- Keep changes minimal and task-focused.
- Prefer deterministic verification over assumptions.
