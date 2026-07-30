---
name: godot-sprite-alignment
description: "Use when tuning sprite frame offsets, aligning animation frames, integrating new sprite sheets like ryu_sheet_1, fixing visual jitter, or validating player animation alignment in this Awash repository."
---

# Godot Sprite Alignment

## Purpose

Provide a repeatable workflow for tuning and validating player sprite alignment across animations and frames.

## Use When

- A sprite sheet is swapped or added.
- Animation frames appear to jitter, drift, or snap between states.
- The user asks to "align frames", "tune offsets", "fix animation alignment", or "make this sheet line up".
- Per-frame offsets need updating for combat or movement readability.

## Primary Targets In This Repository

- `scripts/player/player.gd`
- `scenes/player/player.tscn`
- optional supporting visual logic in `scripts/player/player_sprite_factory.gd`

## Alignment Workflow

1. Confirm active sheet path and toggle behavior.
2. Confirm offset source dictionary for the active sheet.
3. Triage visible issues by animation group:
   - `walk`
   - `run`
   - `jump_up`
   - `jump_down`
   - `attack`
   - `hurt`
4. Apply minimal per-frame offset edits first; avoid changing unrelated animations.
5. Re-check transitions between states, not only isolated loops.

## Tuning Rules

- Prefer small deltas (1 to 3 px equivalent) before larger moves.
- Keep feet/ground contact visually stable during locomotion.
- Preserve weapon or hand silhouette readability on attack frames.
- Avoid compensating with global scale or anchor when a frame offset solves it.
- Keep default-sheet offsets unchanged unless explicitly requested.

## Ryu Sheet Guidance

For `ryu_sheet_1` integration:

- Use separate offsets from default player sheet offsets.
- Keep sheet selection behind an explicit toggle/export variable.
- Verify that idle-to-walk, walk-to-run, and jump transitions do not shift center mass unexpectedly.

## Validation Gates

After edits:

1. `./.venv/bin/gdformat scripts/player/player.gd`
2. `./scripts/quality/lint.sh`
3. `./scripts/quality/test.sh`
4. Run `./scripts/quality/playtest.sh` when runtime behavior or scene flow was touched.

## Reporting Template

Return results in this structure:

1. Active sheet mode and files edited.
2. Offsets updated by animation/frame.
3. Validation results (lint/test/playtest).
4. Remaining visual risks and next tuning candidates.

## Constraints

- Keep changes task-focused and minimal.
- Do not rewrite animation architecture unless requested.
- Maintain existing scene/script wiring whenever possible.
