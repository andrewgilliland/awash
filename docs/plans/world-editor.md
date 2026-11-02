# Plan: The World editor

Agreed 2026-11-02. The World editor is a local web app for laying out the World, Region by Region and Room by Room, and for painting each Room's tiles from its Region's sheets.

## Decisions

- **Local only.** It runs on `localhost` and reads and writes files in this repo. It is never hosted, because it shows the packs' art and their licences forbid redistributing it.
- **What it owns.** The World's data (Regions, Rooms, their places, sizes, Exits, markers and the Plan) and each Room's tile layers. Everything else in a Room stays in Godot: Entries, Exit areas, enemies, Mara, the Gate and walls.
- **The World's data moves to `assets/world.json`.** `scripts/core/world.gd` reads it, and its interface is unchanged. See `docs/adr/0001-world-data-in-json.md`.
- **Stack.** Vite and TypeScript in `tools/world-editor/`, with a small file API in Vite's dev server and Vitest for its tests. It starts with `npm run world-editor`.
- **One set of rules.** The editor doesn't copy the World's rules into TypeScript. A **Check** button runs `./scripts/quality/test.sh` and shows which tests pass and fail.
- **Drawing a Room.** Its tile layers are drawn from the real sheets in the game's order, on a flat sky colour instead of the Background. A grid shows the screen edges and Exits.
- **Editing the World.** The World view is drawn like `draw_map.sh --plan` and can show one Region or all.
  - Drag out screens to add a Planned Room, and move or resize Planned Rooms.
  - Click a Room's edge to add or remove an Exit. A side Exit adds the matching one next door; a south Exit can be a Drop.
  - Set a Room's Region and markers.
  - Moving a built Room changes only its plan.
- **Building a Room.** A Planned Room's **Build** button writes its scene from a template: the Room script, tile layers, walls, an Entry and Exit area per Exit wired to the neighbour's Entry, and the Player. Its World record gains the scene. Moving a built Room to its planned place stays a hand job, with tests and playtests.
- **Painting.**
  - Pick a tile or a block from a sheet; paint, erase, fill a rectangle and eyedrop.
  - Show or hide each layer; undo and redo.
  - Terrain paints only terrain tiles; the scenery layers paint from the scenery sheets.
  - Saving writes only the changed layers' tile data.
  - No auto-tiling yet.
- **Saving safely.** The editor writes files directly, and git is the undo between sessions. It refuses to save a file that changed on disk since it was loaded. Keep a Room's scene closed in Godot while painting it.
- **The Aseprite sketches** in `room_layouts/` are retired: no new ones, and the old ones and the test comments citing them go in a later tidy-up.

## Order of work

Each step is its own PR, built test-first.

1. The World's data into `assets/world.json`, with the ADR. No change in behaviour. *(Done.)*
2. The editor's skeleton: `npm run world-editor`, a read-only World view and Room view, and the Check button. *(Done.)*
3. Editing the World. *(Done.)*
4. Painting tiles, and saving safely. *(Done.)*
5. Building a Planned Room.
