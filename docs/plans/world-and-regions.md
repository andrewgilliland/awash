# Plan: The World, Region records and every-Room tests

Agreed 2026-11-01. Nothing here is built yet; this is the order and shape of the work.

## Decisions

- The **World** is every Region and every Room, with where each Room sits and how many screens it spans; the Map draws it. `scripts/core/world_map.gd` becomes `scripts/core/world.gd` and holds only the World. The Map Panel's `layout` moves beside the Map Panel as `scripts/ui/map_layout.gd`, and `tests/world_map_tests.gd` follows it as `tests/map_layout_tests.gd`, keeping its made-up Rooms.
- The World stays as typed GDScript constants: no Resources, no `class_name`.
- Callers ask the World questions instead of indexing its dictionaries: which Room a scene is, a Room's scene, size, Region, Background and theme, and which Rooms there are. Changing the World's shape is then an edit in one file.
- Each Region is a record keyed by an id that is also its asset folder's name (`&"waking_coast"`). It holds its Map name ("Waking Coast"), its Region theme, its default Background and its named Background variants (`cave`), with every path written out in full so `asset_path_tests` checks them. Rooms name their Region by id. `REGION_MUSIC` goes.
- A Room's entry names a Background variant only when it uses one: the sea cave and the undertow say `background = &"cave"`; every other Room shows its Region's default.
- Tile sheets stay set on each scene's tile layers; the World holds no sheet paths. The every-Room test checks each layer against the folder named by its Region's id.
- The Room script (`scripts/core/main.gd`) is the only part that looks itself up in the World, by its own scene, when it loads. From that it:
  - sets its camera limits to its size times the screen (160x144);
  - adds its Background behind everything and tells it where the Room sits in the world;
  - plays its Region theme.
- The Room no longer reads its id from the Run. The Run still remembers which Room the Player is in, for the Map Panel.
- The Background knows nothing of the World: it is told the Room's place, and its tests can hand it any place.
- The scenes drop their `Background` instances and their camera limits. Accepted cost: a Room opened in the editor shows no Background.
- A scene the World doesn't hold (such as `scenes/main.tscn`) loads with no Background, camera limits or theme, and reports an error naming the scene, like the Exit's "not on the Map" error.
- Layer order is one rule for every Room: scenery layers, then `Terrain`, `Props`, `Entries` and `Player`, with the added Background behind them all. Each Room's landmark test names the layers that Room has.
- Out of scope: the Safe spoke (the Region record leaves room for its own name and theme later); renaming `main.gd` to `room.gd`, which waits on the decision about `scenes/main.tscn`; the Rooms' `Bounds` walls.

## PR 1: `feature/every-room-tests` (tests only, no behaviour change)

- `tests/every_room_tests.gd`, looping over the World, each test named "Every Room …":
  - has a scene (from `room_exit_tests`), and every Exit leads to an Entry;
  - keeps its camera inside its size;
  - draws its scenery behind its `Terrain`, then `Props`, `Entries` and `Player`;
  - keeps its tiles inside its size;
  - draws only from its Region's sheets (from `region_tile_sheets_tests`);
  - shows its Region's Background, or the cave variant (from `region_background_tests`);
  - plays its Region's theme (from `music_tests`).
- The nine Room test files drop `LAYER_ORDER`, their layer-order tests and their camera-limit tests. Each keeps what is its own: landmarks, Entries, walls and Exits, enemies and props, and Room 1's place west of the rune shore.
- Checks of the art itself stay where they are: the cloud tiles, the seams between Backgrounds at each Exit, every terrain tile collides, no scenery tile collides.
- `tests/test_runner.gd` registers the new module; `docs/testing.md` lists it.
- Done when typecheck, lint, tests and every playtest pass with no scene or script changed, and a mutation (one Room's camera limit a screen short, one Room's tile outside its size) turns the module red.

## PR 2: `feature/world-and-regions`

Test-first against PR 1's module, one behaviour at a time, each its own commit:

1. Split `world_map.gd` into `world.gd` and `scripts/ui/map_layout.gd`; callers ask the World's questions. No behaviour change.
2. Region records: Rooms name their Region by id; the Map name and the Region theme come from the record.
3. The Room finds itself in the World by its scene, and reports a scene the World doesn't hold.
4. Camera limits come from the World; the scenes' limits are removed.
5. The Background comes from the World: the Room adds it and tells it its place; the scenes' instances are removed and `region_background.gd` drops its World lookup.

- A rendered check of every Room against `dev`: pixel-identical, the Background included.
- Done when typecheck, lint, tests and every playtest pass, the renders match, and no Room scene holds a camera limit or a Background.

## Risks

- "Keeps its tiles inside its size" may catch a Room whose tiles spill over its edge today. PR 1 finds and fixes it, with a render to show nothing visible changed.
- Once the Room adds its Background in `_ready`, a Room instantiated without entering the tree has none. The every-Room Background check, and any test that looks for the Background, must add the Room to the tree first.
- Editing all nine scenes can churn their uids or re-save unrelated resources. Verify in a clean checkout before each PR, as with the tile-sheet split.
