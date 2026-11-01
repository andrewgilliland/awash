# Plan: Regions, parallax backgrounds and tile sheets

Agreed 2026-11-01. Nothing here is built yet; this is the order and shape of the work.

## Decisions

- A "level" is a **Region** (such as the Waking Coast); a **Room** is one scene in it. Tile sheets, backdrops and asset folders are organised per Region.
- Each Region has a **Background** of parallax layers behind its Rooms' tiles: sky about 0.1x the camera, far about 0.3x, near about 0.6x, the Room's tiles at 1x, and an optional **Foreground** in front of the Player about 1.2x. Layers also move vertically at the same rates, and the sky extends upward. Clouds can drift on their own.
- The Background carries on across Exits: each Room sets its layers from its place on the Map, so the far layers are where the Player left them.
- One Background scene per Region, used by every Room in it, with a variant where needed: the sea cave and the undertow use a cave Background with no sky (a dark rock wall at 0.3x, drips and glints at 0.6x).
- The Waking Coast's Background takes Room 1's tropical look (gradient sky with sun and clouds, jungle haze, sea and surf); the violet-sky backdrops retire.
- Layer art is wide strips (320 px, two screens) that repeat sideways, not tiles.
- Each Region has a **terrain** tile sheet (collides, including one-way ledges) and a **scenery** tile sheet (never collides; behind the Player or in front as a Foreground layer).
- Environment art and music are kept by Region; characters and items by thing, with their sounds beside them. Enemies stay outside Regions, since one kind can appear in more than one.
- An asset is in use when a scene, resource, script or test references it, or it is the Aseprite source of one that is. Anything else is deleted (git history keeps it), except future work, which moves to its future home. `.DS_Store` goes into `.gitignore`.
- Third-party art is credited in `assets/CREDITS.md`: pack name, author, link, licence.

## Before starting

- Land `feature/jungle-room-1` and the Reefback PR (#56) first: all three PRs move or change the same files.
- Needed from the project owner: the pack name, author, link and licence (or "delete it") for `tropical_island_1` and its sources (`jungle_1`, `jungle_canopy_1`), and for `Tree-Assets.png`, `forest_tileset.png`, `world_tileset.png` and `rough_tropical_island_1.png`.

## PR 1: `chore/assets-by-region` (moves only, no behaviour change)

```
assets/
  regions/waking_coast/   tiles/   backdrops/   room_layouts/   music/
  player/   npcs/mara/   enemies/<kind>/ (sheet + its sounds)   items/   ui/   fonts/   sfx/ (shared only)
  CREDITS.md
```

- `waking_shores_N.aseprite` becomes `regions/waking_coast/room_layouts/<room id>.aseprite`, named for the Room it lays out; the Room tests' comments follow.
- Delete superseded art: the old `waking_coast_1` tiles, `tropical_beach_1`, `vael_1`, `waking_shores_1` and `_2`, any pack sheets marked for deletion, and the `.DS_Store` files. `ilyr_voss_1` moves to `npcs/` or `enemies/`.
- `scripts/tools/move_asset.py` moves each asset with its `.import` file (`git mv`) and rewrites every `res://` path in scenes, resources, scripts, tests and docs. Godot's uids carry over.
- A new test: every `res://` path the game references exists.
- Done when typecheck, lint, tests and every playtest pass with nothing else changed.

## PR 2: `feature/parallax-backgrounds`

- Glossary: **Background**, **Foreground**.
- `scenes/regions/waking_coast/background.tscn`: `Parallax2D` layers sky, far, near as above. `cave_background.tscn`: the cave variant.
- Each Room's entry in `scripts/core/world_map.gd` names its Background (the Region's by default; the cave variant for the sea cave and undertow). The Room script adds it and offsets it from the Room's Map cell times the screen size (160x144).
- Remove every Room's `Backdrop` sprite and Room 1's tile-painted sky and clouds.
- Art: the sky, far and near strips are arranged from pieces already in the Region's sheets; the cave strips start as flat placeholder colours, to be drawn.
- Tests: the layers sit behind Terrain and the Foreground in front of the Player; every Room uses its Region's Background or the cave variant; for every pair of Rooms joined by an Exit, the far layer lines up on screen at the crossing.
- A rendered check of the salt cliffs for the vertical parallax.

## PR 3: `feature/region-tile-sheets`

- Split today's `waking_coast_2` and `tropical_island_1` sheets into the Waking Coast's `terrain` and `scenery` sheets.
- Each Room's `Terrain` layer uses the terrain sheet; its scenery layers use the scenery sheet; an optional `Foreground` layer draws in front of the Player.
- A script remaps every Room's tiles from the old sheet positions to the new; the remap is its own commit.
- Tests: every terrain tile collides or is one-way; no scenery tile collides; every Room uses only its Region's sheets. The Room tests' landmark cells move to the new positions.
- A rendered check of every Room.

## Risks

- PR 1 touches almost everything, so it waits for the other work to land.
- A wrong tile remap shifts tiles silently; each Room's landmark test and a rendered check guard it.
- Vertical parallax in tall Rooms needs a rendered check, not only tests.
