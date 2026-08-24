# Testing

Awash includes lightweight headless test and deterministic playtest runners.

## Run

```bash
./scripts/quality/test.sh
./scripts/quality/playtest.sh
```

## Current Coverage

- The player scene loads with a `CharacterBody2D` and `AnimatedSprite2D`.
- Idle uses frame 0 from the 16x16 `player_1.png` grid.
- Walk uses frames 0 and 1 from the same grid.
- The integrated main scene loads with its player, world, and pause menu.
- Runtime state defaults remain valid.
- The deterministic main-scene spawn remains stable.

## File Ownership

- `scripts/core/input_setup.gd` owns input action setup and default bindings.
- `scripts/player/player.gd` owns all current player movement, state, and animation logic.
- `scenes/player/player.tscn` owns the player node structure and collision shape.
