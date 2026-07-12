# Awash

Awash is a new 2D metroidvania-style action RPG prototype built in Godot 4.4.

## Current Status
- Project bootstrap complete.
- Playable foundation scene is in place.
- Player controller includes movement, coyote time, and jump buffering.
- Double-jump support is coded and can be toggled by setting `has_double_jump = true` on the player.
- Input bootstrap supports keyboard and gamepad defaults at runtime.
- Step 2 setup is in place: collision layer names and standards documentation.

## Run
1. Open `awash` in Godot 4.4.
2. Run the main scene at `res://scenes/main.tscn`.
3. Move and jump around the graybox room.

## Controls
- Move: Arrow keys / WASD / Left stick
- Jump: Space or C / Gamepad A
- Melee (reserved): X / Gamepad X
- Ranged (reserved): V / Gamepad B
- Interact: E / Gamepad Y
- Pause: Esc / Menu
- Map: Tab / View

## Quality Gates
- Typecheck: `./scripts/quality/typecheck.sh`
- Lint/Format check: `./scripts/quality/lint.sh`
- Tests: `./scripts/quality/test.sh`

## Pre-commit Hook
- Install hook: `./scripts/install_hooks.sh`
- Hook path: `.githooks/pre-commit`
- On each commit, runs: typecheck, lint/format check, tests

## Step 2 Standards
- See `docs/step-2-standards.md` for input action names, collision matrix, and naming conventions.

## Next Implementation Targets
1. Add player state machine with locomotion + combat branches.
2. Implement melee hitbox windows and ranged projectile scene.
3. Add room transitions and persistent progression flags.
4. Implement the first double-jump unlock event and gated route.
