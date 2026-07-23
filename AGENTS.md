# AGENTS.md

This file provides guidance for coding agents working in this repository.

## Project

- Name: Awash
- Engine: Godot 4.4
- Main scene: `res://scenes/main.tscn`
- Current language: GDScript

## Goals For Agents

- Make minimal, task-focused changes.
- Preserve existing scene/script wiring unless the task requires changes.
- Keep tests and quality gates passing before finishing work.

## Setup

- Python dev tools are expected in a local venv.
- Install tools when missing:
  - `python3 -m venv .venv`
  - `./.venv/bin/pip install -r requirements-dev.txt`

## Run And Quality Commands

- Typecheck: `./scripts/quality/typecheck.sh`
- Lint + format check: `./scripts/quality/lint.sh`
- Tests: `./scripts/quality/test.sh`
- Playtests: `./scripts/quality/playtest.sh`

## Pre-commit

- Hook path: `.githooks/pre-commit`
- Hook runs, in order:
  1. `./scripts/quality/typecheck.sh`
  2. `./scripts/quality/lint.sh`
  3. `./scripts/quality/test.sh`

## Lint/Format Notes

- Lint uses `gdlint` and enforces max line length (100).
- Format check uses `gdformat --check` over `scripts` and `tests`.
- If `gdformat` is not in shell PATH, use:
  - `./.venv/bin/gdformat <file_or_folder>`

## Input Conventions

- Input actions are bootstrapped by `scripts/core/input_setup.gd`.
- Reuse existing action names (`move_left`, `jump`, `pause`, `map`, etc.) before introducing new ones.

## Scene/Script Conventions

- Prefer adding reusable UI/features as dedicated scenes under `scenes/` with scripts under `scripts/`.
- Keep node paths stable when possible; if changed, update tests accordingly.
- Current pause menu scene path: `res://scenes/ui/pause_menu.tscn`.

## Testing Expectations For UI Changes

- For pause/menu changes, verify at minimum:
  - `./scripts/quality/lint.sh`
  - `./scripts/quality/test.sh`
- Run `./scripts/quality/playtest.sh` for behavior-sensitive changes in `main.tscn` or runtime flow.

## Commit Hygiene

- Stage only files related to the requested task.
- Do not include unrelated scene/editor churn.
- Keep commit messages short and descriptive.
