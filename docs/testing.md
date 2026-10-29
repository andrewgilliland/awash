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
- The game starts at the start screen, and the first Room loads with its player, world, and pause menu.
- The Pause menu pauses on Home, opens each Panel from its button, returns Home on Back with focus on the opening button, resumes play, pairs every button with a Panel, disables a button with no Panel, fits the 160x144 screen, draws all text in the pixel font, and names the Room's region on the Map, and keeps Rooms past the Map's edges inside its Panel (`tests/pause_menu_tests.gd`, run after one frame so the menu is in the tree).
- The Map centres the current Room, shows only visited Rooms, marks where the Player stands, and holds the Room every Run begins in (`tests/world_map_tests.gd`).
- Every Room on the Map has a scene, every Exit leads to an Entry in a Room on the Map, and the Waking Coast Rooms connect both ways, shore to first Room, shore to cliffs, cliffs to graveyard, and the loop from graveyard down to cave and back to cliffs (`tests/room_exit_tests.gd`).
- The first Room (`scenes/rooms/waking_coast_1.tscn`) lays out its layers and landmarks as an open surf beach with no rune props or pool, starts Vael in the middle of the screen, keeps Blacktide hidden in the sand until the Intro shows it, and walls its west edge (`tests/waking_coast_room_tests.gd`).
- The rune shore Room (`scenes/rooms/waking_coast_2.tscn`) is two screens wide, enters on the cliff top, scrolls its camera inside the Room, and leads east into the salt cliffs (`tests/waking_coast_room_2_tests.gd`); a playtest walks from the first Room into the shore and back.
- The salt cliffs Room (`scenes/rooms/waking_coast_3.tscn`, laid out in `assets/waking_shores_4.aseprite`) is two screens tall: it enters on the beach level with the rune shore, keeps a Scavenger in its tidal pool, climbs one jump at a time (a jump rises two tiles, worked out from the Player's jump and gravity) up stone ledges and wreck decks to the cliff top, leaves its highest ledge out of reach for a double jump, scrolls its camera up the Room, leads east from the cliff top into the wreck graveyard and from a tunnel at its foot into the sea cave, and walls its top screen's west edge (`tests/waking_coast_room_3_tests.gd`). Playtests walk from the shore's east end into the cliffs and back, and climb from the beach to the cliff top with real input.
- The wreck graveyard Room (`scenes/rooms/waking_coast_4.tscn`, laid out in `assets/waking_shores_5.aseprite`) is two screens wide: it enters on a cliff level with the salt cliffs' top, runs east along a beach of two tidal pools that needs none of the decks, has wreck decks that lead a jump at a time up to the stern's crate off the main way, keeps a Scavenger in its second pool, drops through a sinkhole at the beach's east end into the sea cave, and walls its east edge until the rune road exists (`tests/waking_coast_room_4_tests.gd`). Playtests walk from the cliffs' top into the graveyard and back, and hop the decks up to the stern with real input. `tests/room_reach.gd` holds the reach check both Rooms use: the surfaces to stand on in a Room's Terrain, and which a walk, a single jump or a drop reaches.
- The sea cave Room (`scenes/rooms/waking_coast_5.tscn`, laid out in `assets/waking_shores_6.aseprite`) is two screens wide under the wreck graveyard: rock or the cave's dark fills every cell, a shaft drops in from the graveyard's sinkhole too tall to climb back up, its floor runs from the shaft past a pool to a tunnel west into the salt cliffs, a shelf a jump up holds a crate, and its east edge is walled (`tests/waking_coast_room_5_tests.gd`). A playtest walks the loop with real input: along the graveyard's beach, down the sinkhole, through the cave and out at the cliffs' foot.
- Health starts full, takes hits, blocks them while invulnerable and stops at zero (`tests/health_tests.gd`).
- The Scavenger brain patrols, winds up only when the Player is near and level, lunges then recovers, is knocked back by a hit and stays still once defeated (`tests/scavenger_brain_tests.gd`).
- The Player controller is knocked back by a hit, ignores input while stunned and loses an attack to a hit (`tests/player_controller_tests.gd`).
- The Player and Scavenger carry their Hurtboxes and Hitboxes on the right layers, the sword is live only during an Attack, a hit costs the Player Health and knocks it away, and the rune shore keeps a Scavenger in its pool (`tests/combat_scene_tests.gd`).
- Playtests: the sword defeats the Scavenger, its lunge hurts the Player, and a defeated Player starts the Run over.
- Landing after a real fall and starting an Attack make sounds, other state changes and a moment in the air are silent, and the controller reports a jump but not a walk off a ledge (`tests/player_sounds_tests.gd`, `tests/player_controller_tests.gd`).
- The Player carries its six sounds on the `SFX` bus and plays them for a jump, a landing, a swing, a sword hit, being hurt and being defeated (`tests/player_sound_scene_tests.gd`).
- The Scavenger growls on its wind-up, sounds its spear on the lunge, croaks when hurt and burbles when defeated, from any state, while recovering and patrolling stay quiet; it carries those four as positional sounds on the `SFX` bus and plays them as its brain changes state (`tests/scavenger_sounds_tests.gd`, `tests/scavenger_sound_scene_tests.gd`).
- The start screen shows its animated logo and a blinking PRESS START, a start press opens the menu on START, moving between options ticks, palms frame its beach, and its theme loops on the `Music` bus (`tests/start_screen_tests.gd`); a playtest waits for the theme, presses START from a Run left in the rune shore, hears the theme fade, and arrives in a fresh Run at the first Room's start Entry.
- The Music autoload plays a track on the `Music` bus, carries on when asked for the track already playing, switches tracks and stops; every Room's region has a looping theme, and a Room starts it when it is ready (`tests/music_tests.gd`); the walk-between-Rooms playtest checks that the Waking Coast theme plays on through the Exit without starting over.
- Dialogue types each line out, a press finishes a line or moves to the next, it ends after its last line, and a line can carry a cue (`tests/dialogue_tests.gd`); the dialogue box shows the speaker and line, holds the Player still and calls out each line's cue as it opens, Mara stands in the first Room with a talk zone drawn from her sheet, a fresh Run is not owed the intro, every line fits the box, and Mara hands Vael his sword on one line (`tests/intro_tests.gd`). Playtests: a new game from START plays the intro, Blacktide leaves the sand, and control comes back; Interact talks to Mara again; a defeat restart has no intro.
- An Interactable sits on the `trigger` layer watching the Player; Interact uses the nearest one in reach, does nothing out of reach or while the Player is held still, its prompt shows only while the Player can act, and Mara is reached through one (`tests/interaction_tests.gd`).
- The Run begins in `waking_coast_1` at its `start` Entry, enters Rooms at Entries, starts over, and ignores empty ids (`tests/run_state_tests.gd`).
- The Player appears at the Run's Entry in the first Room.
- The deterministic main-scene spawn puts the Player on the default Entry, over a `WorldLayer` with tiles.
- The art checks behind `scripts/quality/art.sh` (`scripts/tools/art_checks.gd`) find colours off a palette, a surface's lit top edge, art that reaches its collision, whether a value reads against what is behind it, a seam across a tile edge, a loop's jump from last frame to first, and a figure's separate pieces (`tests/art_checks_tests.gd`, on small made-up pictures).
- End-to-end playtests (`tests/playtest_runner.gd`) play the real first Room, with autoloads, input action events and physics frames at `--fixed-fps 60`: the Player walks right, jumps and lands, plays an attack to its end and back to idle, and pause freezes and resumes play.

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
- `scripts/core/music.gd` (the `Music` autoload) owns the region music: it outlives scene changes, so a Room asking for the theme already playing lets it play on. `WorldMap.REGION_MUSIC` names each region's theme, and the Room script asks for it. The themes are made by `scripts/tools/make_music.py`, where each song is a block of data.
- `scripts/ui/dialogue.gd` owns how a conversation types out and advances; `scripts/ui/dialogue_box.gd` shows it, holds the Player still (`controls_locked`), and lets go a frame after closing so the closing press can't jump. `scripts/world/interactable.gd` is anything Interact can use: it watches for the Player on the `trigger` layer, shows the arrow prompt (`assets/ui/interact_prompt.aseprite`) while the Player can act, and reports being used; the Player body's `interact()` uses the nearest one in reach. `scripts/npcs/mara.gd` is Mara: her sprite (`assets/sprites/npcs/mara/mara_venn_1.aseprite`), her walk, and her Interactable, which opens her reminder lines. `scripts/story/intro.gd` plays the Intro in the first Room when `RunState.intro_pending` is set, which only the start screen's START does: it shows Blacktide stuck in the sand (`assets/sprites/weapons/blacktide_stuck.aseprite`), has Mara carry it over, and hides it on the line cued `hand_over`.
- `scripts/core/room_exit.gd` owns crossing an Exit: it enters the next Room in the Run and swaps to that Room's scene from the Map.
- `assets/ui/awash_theme.tres` gives the menus the 5x7 pixel font (`assets/fonts/awash_pixel_5x7.png`, drawn in its `.aseprite`) and the game's palette.
- `scripts/core/main.gd` places the Player at the Run's Entry, using the Room's `Entries` markers (a new Run starts in `scenes/rooms/waking_coast_1.tscn`).
- `scripts/ui/start_screen.gd` owns the start screen (`scenes/ui/start_screen.tscn`, the main scene): PRESS START opens the START / QUIT menu, and START begins a new Run in the first Room. Its logo is drawn in `assets/ui/awash_logo.aseprite`. Its theme (`assets/audio/music/start_theme.wav`, made by `scripts/tools/make_music.py`) fades in a moment after the screen appears, loops on the `Music` bus, and fades out under the start chime.

## Art report

`scripts/quality/art.sh` runs the art checks over the game's art and Rooms against `docs/art-style.md`: the palette, readability, collision against art, seams, loops and character fit. `scripts/tools/room_render.gd` draws each Room flat from its tiles, headless. The report writes `build/art-report/` (ignored by git): `report.json`, plus a contact sheet of every Room at its Map position in colour, greyscale and a 25% thumbnail. It exits 1 while any check fails, so it stays out of the pre-commit gate until the re-skinned art lands.
