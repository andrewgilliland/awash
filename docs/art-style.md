# Art Style

How Awash's pixel art is drawn, from Phase 0 of [the art fidelity plan](art-fidelity-plan.md). The fidelity target is `assets/tilesets/rough_tropical_island_1.png`, used as a reference only. The mood is Awash's own: a violet storm-dusk over the black surf.

## Screen and grid

- The screen is 256x144: 16x9 tiles of 16 px, shown at 5x.
- Characters are about 24 px tall, in 32x32 frames.
- Everything is drawn at 1x, with no mixed pixel sizes, rotation or scaling.

## Palette

Use only `assets/palettes/awash_dusk.gpl`: 72 colours in 18 named ramps. `awash_dusk.aseprite` shows each ramp as a row, and its slices name them. Every ramp runs dark to light and is **hue-shifted**: shadows lean cool and violet, lights lean warm.

| Ramp | Shades | For |
|---|---|---|
| Ink | 2 | outlines and the deepest shadow |
| Sky, Cloud | 5, 3 | the dusk sky, haze and cloud streaks |
| Sea, Foam | 5, 2 | the black surf, water and foam |
| Sand, Wet sand | 5, 3 | dry and wet beach |
| Rock | 5 | cliffs, ledges and rune stones |
| Rune | 5 | rune glow, the cave's dark, and Tidefen's lanterns |
| Wood | 5 | wrecks, decks, stilts and crates |
| Foliage | 5 | palms and reeds |
| Brass | 4 | the bell, fittings and coins |
| Skin, Cloth | 4, 3 | Vael |
| Mara | 3 | Mara's hair and cloth |
| Scaled | 4 | the Scavenger |
| Danger | 3 | hurt flashes and hazards |
| UI | 6 | menus and the dialogue box only, never in the world |

A material uses 3-5 shades of its own ramp. It borrows across ramps only for shadow, by stepping toward Ink or Rock, and for reflected sky, from the Sky ramp.

## Light

- **One key light**: the low moon over the sea, **upper right**.
- Tops and right-facing sides take a material's lightest shades. Undersides and left sides take its darkest.
- Rune glow is the only other light. It lifts nearby rock by one shade within a few pixels.

## Outlines

- **Selective outlines:** use Ink on the shadow side and on the bottom, and the material's darkest shade on lit edges.
- There are no outlines inside a mass of the same material. A cliff is one shape, not a grid of bordered tiles.
- Characters and props carry a full, readable outline. Terrain is outlined only where it meets the air.

## Shading and texture

- Shade forms with 3-4 shades. Don't pillow-shade, meaning no darkening every edge evenly.
- Texture comes from clusters of 2 px or more, not lone pixels, and covers at most about 10% of a surface, such as sand speckle or cracks in rock.
- **Dithering** is allowed only in backgrounds and sky gradients, at 50% checker at most.

## Readability

- **Solid ground** shows a lit top edge 2 px deep in its lightest shade. Nothing else gets that edge.
- **One-way ledges and decks** show a lit top 2-3 px deep and a clear shadow underneath, so they read as standable from below. Their collision is the tile's top 7 px.
- **Scenery** such as backgrounds, far palms, hulls, masts and the cave's dark is lower in contrast and pulled toward the Sky or Sea ramp. It never takes the solid-ground top edge.
- **Shallows:** the water sits on sand. The Player stands 10 px down, so the sand line should read about there.
- Characters must read as a solid silhouette in one colour against both sand and the night sea.

## Tiles

`assets/tilesets/waking_coast_3.aseprite` is the template. Its layers:
- **Art:** paint here.
- **Reference:** today's tiles, faint and locked.
- **Collision:** a locked guide. A red border marks a solid slot, a yellow line marks a one-way slot's 7 px collision edge, and a blue line marks the shallows' standing height.

Every slot has a named slice, for example `(6,5) tide line - solid - 4 frames`. In Aseprite, choose View, then Show, then Slices to see them.

- **Never move a slot.** Every Room is built from these coordinates, so drawing into a slot re-skins every Room that uses it.
- New pieces, such as slopes, more edges and larger props, go in **new rows below row 10**.
- Same-material edges must match across the 16 px seam on all four sides.
- Slots marked "4 frames" animate at 0.15 s per frame. Draw all four frames and make them loop.
- Large props, such as palms, wrecks and the stilt houses, are drawn as whole pictures, then cut along the 16 px grid.

## Characters

The templates are `assets/sprites/vael_32.aseprite`, `npcs/mara/mara_venn_32.aseprite` and `enemies/scavenger_32.aseprite`, in 32x32 frames. Their layers:
- **Art:** paint here.
- **Reference:** today's 16 px figure, faint, for scale.
- **Guides:** the feet line on the bottom row, plus the collision and hurt boxes, centred on x 16.

- Each animation is a tag, with frame counts and timings already set. For example, Vael has idle 4, walk 6, jump 3, charge 2, attack 4, hurt 1, lying 1, get_up 2 and defeat 3.
- Feet stand on the bottom row, and the body stays within the boxes in the frames where the box matters.
- Vael faces **left** in every frame; the game flips him. Draw Blacktide into his charge and attack frames.

## The style target

`assets/style_target.aseprite` is the first Room at 256x144:
- **Blockout layer** (bottom): flat palette fills.
- **Paint layers** above it: Sky, Far, Mid, Terrain, Props and Characters.

Paint the real screen over the blockout. The composition can change. **We agree on this one screen before any production art starts.**
