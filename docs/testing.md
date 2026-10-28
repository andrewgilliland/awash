# Testing

Awash includes lightweight headless test and deterministic playtest runners.

## Run

```bash
./scripts/quality/test.sh
./scripts/quality/playtest.sh
```

## Current Coverage

- The Player controller follows each Movement and States rule in `docs/specs/player-spec.md` (`tests/player_controller_tests.gd`).
- The Player rig follows each Animation rule, and its table is complete: a row for every state and one sword offset per sword frame (`tests/player_rig_tests.gd`).
- The player scene wires the rig: its sprites follow controller state and facing, driven through the body's `controller`.
- The integrated main scene loads with its player, world, and pause menu.
- The Pause menu pauses on Home, opens each Panel from its button, returns Home on Back with focus on the opening button, resumes play, pairs every button with a Panel, and disables a button with no Panel (`tests/pause_menu_tests.gd`, run after one frame so the menu is in the tree).
- The Run begins in `room_1` at its `start` Entry, enters Rooms at Entries, starts over, and ignores empty ids (`tests/run_state_tests.gd`).
- The Player appears at the Run's Entry in the main scene.
- The deterministic main-scene spawn puts the Player on the default Entry, over a `WorldLayer` with tiles.
- End-to-end playtests (`tests/playtest_runner.gd`) play the real main scene, with autoloads, input action events and physics frames at `--fixed-fps 60`: the Player walks right, jumps and lands, plays an attack to its end and back to idle, and pause freezes and resumes play.

## File Ownership

- `scripts/core/input_setup.gd` owns input action setup and default bindings.
- `scripts/player/player_controller.gd` owns player state transitions, facing, and horizontal movement.
- `scripts/player/player_rig.gd` owns the Player's sprite frames, animations, sword visibility and placement.
- `scripts/player/player.gd` owns input reading, gravity and collision movement.
- `scenes/player/player.tscn` owns the player node structure and collision shape.
- `scripts/core/run_state.gd` (the `RunState` autoload) owns the Run: the current Room, the Entry the Player came through, and visited Rooms.
- `scripts/ui/pause_menu.gd` owns pausing and Panel switching; it pairs each `<Name>Button` in `%MenuButtons` with `<Name>Panel` in `%ContentRoot` by name, so a new Panel is a scene-only change.
- `scripts/core/main.gd` places the Player at the Run's Entry, using the Room's `Entries` markers (the game starts in `scenes/rooms/waking_coast_1.tscn`).
