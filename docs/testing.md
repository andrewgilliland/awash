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
- The Pause menu pauses on Home, opens each Panel from its button, returns Home on Back with focus on the opening button, resumes play, pairs every button with a Panel, disables a button with no Panel, fits the 160x144 screen, draws all text in the pixel font, and names the Room's region on the Map (`tests/pause_menu_tests.gd`, run after one frame so the menu is in the tree).
- The Map centres the current Room, shows only visited Rooms, marks where the Player stands, and holds the Room every Run begins in (`tests/world_map_tests.gd`).
- Every Room on the Map has a scene, every Exit leads to an Entry in a Room on the Map, and the two Waking Coast Rooms connect both ways (`tests/room_exit_tests.gd`).
- The rune shore Room (`scenes/rooms/waking_coast_2.tscn`) is two screens wide, enters on the cliff top, scrolls its camera inside the Room, and walls its east edge until Tidefen exists (`tests/waking_coast_room_2_tests.gd`); a playtest walks from the first Room into the shore and back.
- Health starts full, takes hits, blocks them while invulnerable and stops at zero (`tests/health_tests.gd`).
- The Scavenger brain patrols, winds up only when the Player is near and level, lunges then recovers, is knocked back by a hit and stays still once defeated (`tests/scavenger_brain_tests.gd`).
- The Player controller is knocked back by a hit, ignores input while stunned and loses an attack to a hit (`tests/player_controller_tests.gd`).
- The Player and Scavenger carry their Hurtboxes and Hitboxes on the right layers, the sword is live only during an Attack, a hit costs the Player Health and knocks it away, and the rune shore keeps a Scavenger in its pool (`tests/combat_scene_tests.gd`).
- Playtests: the sword defeats the Scavenger, its lunge hurts the Player, and a defeated Player starts the Run over.
- Landing after a real fall and starting an Attack make sounds, other state changes and a moment in the air are silent, and the controller reports a jump but not a walk off a ledge (`tests/player_sounds_tests.gd`, `tests/player_controller_tests.gd`).
- The Player carries its six sounds on the `SFX` bus and plays them for a jump, a landing, a swing, a sword hit, being hurt and being defeated (`tests/player_sound_scene_tests.gd`).
- The Run begins in `waking_coast_1` at its `start` Entry, enters Rooms at Entries, starts over, and ignores empty ids (`tests/run_state_tests.gd`).
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
- `scripts/core/world_map.gd` owns where each Room sits on the Map and lays the Map out; `scripts/ui/map_view.gd` draws it from the Run and the Player's position.
- `scripts/combat/health.gd` owns Health and invulnerability; `scripts/combat/hitbox.gd` and `scripts/combat/hurtbox.gd` connect a live Hitbox to the Hurtboxes it touches (`docs/specs/scavenger-spec.md` covers the Scavenger).
- `scripts/core/room_exit.gd` owns crossing an Exit: it enters the next Room in the Run and swaps to that Room's scene from the Map.
- `assets/ui/awash_theme.tres` gives the menus the 5x7 pixel font (`assets/fonts/awash_pixel_5x7.png`, drawn in its `.aseprite`) and the game's palette.
- `scripts/core/main.gd` places the Player at the Run's Entry, using the Room's `Entries` markers (the game starts in `scenes/rooms/waking_coast_1.tscn`).
