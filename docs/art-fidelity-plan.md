# Art Fidelity Plan

Raise Awash's pixel art to the fidelity of `assets/tilesets/rough_tropical_island_1.png`, on a wider screen.

## What "higher fidelity" means here

The reference is a promo banner for a commercial pack (Tropical Island Tileset Pack, by Mucho). It is a **style target only**: nothing from it is traced or shipped. Measured against our art:

| | Reference | Awash today |
|---|---|---|
| Tile size | 16 px (art drawn at 1152x360, shown at 2x) | 16 px |
| Colours | deep ramps, 4-6 hue-shifted shades per material | 26 in the whole tileset; Vael has 4 |
| Outlines | dark, selective: lighter where light hits | flat black |
| Shading | one light direction, highlights, soft texture speckle | mostly flat fills |
| Props | large, multi-tile (palms ~64 px, treehouse, rope bridge) | one or two tiles |
| Backgrounds | layered: sky, clouds, sun, far sea with ships, near foliage | one baked backdrop per Room |
| Characters | small but shaded | 16x16, 4 colours |

So the tile grid stays. What changes is palette depth, shading, outlines, prop scale, layered backgrounds, character size, and the screen.

## Decisions

- **Screen: 256x144 (16:9), 16x9 tiles.** It keeps today's 9-tile height, so Rooms keep their rows. The window becomes 1280x720 (5x). 1080p shows small borders at 7x.
- **Palette: Awash's dusk, richer.** Keep the violet storm-dusk mood of the black surf and the memory tempests, with 4-6 shade hue-shifted ramps per material.
- **Characters: about 24 px tall** in 32x32 frames. Vael's collision capsule (20 px tall) barely changes.
- **Who draws:** you draw in Aseprite against the palette and templates set up in Phase 0. I build the TileSets, scenes and tests around the art, and script repetitive variants (frame copies, edge pieces, previews).

## The key move: re-skin, don't re-lay

Every Room's tiles are stored as atlas coordinates, such as sand top at (1,0) and tide line at (6,5). The collisions and animations in the TileSet, and most Room tests, are keyed to those same coordinates. So the new Waking Coast tileset keeps **the same 8x11 slot grid with the same meaning in each slot**. Drawing new art into the slots re-skins all nine Rooms at once. New pieces such as slopes, more edge variants and bigger props go in **new rows** below, so nothing existing moves.

## Phases

Each phase lands as its own PR. Each passes typecheck, lint, tests and playtests, and comes with before and after screenshots. Phases 1 and 2 can run in parallel: one is code, the other is drawing.

### Phase 0 - Style foundation (me, then your sign-off)

- **Master palette** `assets/palettes/awash_dusk.gpl` (with a swatch in `awash_dusk.aseprite`): 72 colours in 18 named, hue-shifted ramps, keeping the UI's colours exactly.
- **Style guide** [`docs/art-style.md`](art-style.md): covers light direction (low moon, upper right), outline rules, ramp use, when dithering is allowed (backgrounds only), texture density, and readability rules (solid ground must read apart from scenery).
- **Templates:**
  - `waking_coast_3.aseprite`: today's 8x11 slot grid, every slot labelled with its role and collision (solid, one-way, scenery), plus the 4 animation frames
  - 32x32 character frame sheets with a feet line and the hitbox overlaid
- **Style target:** one 256x144 mock screen of the first Room, drawn by you over a scripted blockout. We agree on it before any production art.

### Phase 1 - Screen to 256x144 (code, works with today's art)

- `project.godot`: viewport 256x144, window 1280x720.
- Widen the three one-screen Rooms from 10 to 16 columns: the surf beach, the salt cliffs and the Warden's gate. Re-check their reach tests and climb playtests.
- The Map places Rooms from their real size and position in tiles, instead of the fixed 160x144 "screen" in `WorldMap.ROOMS`.
- The dialogue box grows to the new width. The line-fit test goes from 23 to about 38 columns, and the Intro's lines can be rejoined.
- The pause menu, start screen and Map get laid out again for 256x144. The "fits the screen" test changes size.
- The tests' `ROOM_SIZE` and camera limits change for the widened Rooms.

### Phase 2 - Waking Coast tileset re-skin (you draw, I integrate)

- You paint `waking_coast_3.aseprite` slot by slot. I export it, generate `waking_coast_3.tres` by script with the same collisions and animations (never through the editor, which has rewritten the TileSet before), and point the nine Rooms at it.
- New rows: slopes, ground edges, larger palms and wrecks as multi-tile props, more rock variants.
- Tileset tests cover the new rows. I regenerate the layout previews (`waking_shores_*.aseprite`) from the Rooms by script.

### Phase 3 - Layered backgrounds

- Replace each Room's baked `Backdrop` with shared **Parallax2D layers per Region**: sky gradient and moon, clouds, far sea with the black surf and distant wrecks, hills, and near foliage. The animated surf stays at 4 frames.
- Caves (the sea cave and the undertow) get their own dark layered back: rock depth, drips, rune glow.
- The Room tests change from "Backdrop frame equals Room size" to "Room has its Region's parallax layers".

### Phase 4 - Characters at 32x32

- **Vael:** idle, walk, jump, charge, attack, lying, hurt and defeat, with Blacktide drawn into the attack frames.
- **Mara:** idle, walk, carry.
- **Scavenger:** patrol, wind-up, lunge, hurt, defeated.
- **Blacktide in the sand.**
- I update the Player rig's `FRAME_SIZE`, its frame table and sword offsets, the collision and hurt boxes, and the sprite feet test.

### Phase 5 - Props and UI

- The lantern, rune stones, bell, crates and barrels (these become Caches later), the Interact prompt, the dialogue box frame, the pause menu panel, the AWASH logo, and the start screen.
- The pixel font stays at 5x7 unless the wider screen needs a larger one.

### Phase 6 - Clean-up

- Delete superseded art: `waking_coast_1`, `waking_coast_2`, `Tree-Assets`, `forest_tileset`, `world_tileset`, and the old player and enemy sheets.
- Move the reference banner out of `assets/` into `docs/reference/`, so it never ships.

## Risks

- **Hand-drawn art is the long pole.** Phase 2 alone is about 90 tiles plus 4 frames for each animated tile. Draw Phase 0's style target first, so the style isn't changed midway.
- **The open Godot editor has rewritten `waking_coast_2.tres` before.** Generate the new `.tres` by script, and check it before every commit.
- **Licensing:** the reference banner is someone else's commercial art. It belongs in docs as a reference only, never in a build.
