# Plan: The Low Canopy Jungle

Agreed 2026-11-09, from three throwaway layouts drawn with the Map's own code (kept on the `feature/prototype-jungle-layout` branch). Layout A, the Ascent, was chosen over B, which climbed back west over Tidefen. The layout lives in the World as its Plan; draw it with `./scripts/tools/draw_map.sh --plan`.

## Decisions

- Chapter 2 is three Regions: the Low Canopy Jungle, the Shrinekeeper Camp (its Safe spoke), and Smuggler Inlet with the Pirate Fort, which are planned later.
- The way in is off Tidefen's east edge. Its harbour's wall comes out at quay level, and the Exit is there.
- The jungle climbs east and up from the harbour in seven Rooms:
  1. The harbour trail (`low_canopy_jungle_1`, 2×1), at sea level: up root steps past a waterfall into the trees.
  2. The lower terraces (`low_canopy_jungle_2`, 3×2): the shrine keepers' medicine beds behind broken walls, rising east, with a ruined relief of wardens carrying the Book.
  3. The Spore Beast's lair (`low_canopy_jungle_5`, 2×1), a dead end down from the lower terraces.
  4. The canopy walk (`low_canopy_jungle_3`, 2×1), through the trees.
  5. The upper terraces (`low_canopy_jungle_4`, 1×3), three screens up.
  6. The shrine steps (`low_canopy_jungle_6`, 2×1).
  7. The root hollow (`low_canopy_jungle_7`, 1×3), past the camp, down toward Smuggler Inlet.
- The Shrinekeeper Camp (`shrinekeeper_camp_1`, 2×1) sits at the jungle's far end, up in the canopy, and holds its Rest point. It is a Region of its own, the way Tidefen is, and keeps the jungle's sheets and Background.
- On the Map, the jungle is `#3d6b21` and the camp `#7a6a3a`.
- The jungle's look is `assets/tilesets/jungle_1.aseprite`, a mockup drawn for Awash rather than taken from a pack, at twice the game's scale. Its tiles and its three-layer Background are cut from it at half scale: grass and earth, mossy ledges, plank decks, bark, vines and leaves. The terraces' stonework and the relief are drawn in its palette.
- The jungle's theme is made with `scripts/tools/make_music.py`.

## How the Plan is held

- As for the coast and the Undertow (`docs/plans/coast-and-undertow.md`): a built Room's record keeps what is true today, and a Planned Room has no scene.
- A built Room whose Exits lead into Rooms not built yet keeps them shut and carries them in its `plan`, the way the lake's sealed door waits for the Undertow's Boss.
- `tests/world_plan_tests.gd` keeps the jungle climbing east from Tidefen to the camp, and keeps Tidefen as its only way in until Smuggler Inlet is planned.

## Order of work

Each step gets its own grilling and PR.

1. Built: the Plan, the two Regions, the jungle's sheets, Background and theme, Tidefen's east edge opened, the harbour trail, and the lower terraces with their east end and the lair's floor shut. There are no enemies yet.
2. Built: the lower terraces opened east, off a deck over the top bed, onto the canopy walk; the canopy walk, its rope bridge broken in the middle over a forest floor; the upper terraces, with a chest on a shelf only the Double Jump reaches (the jungle's `[DJ-1]` gate); and the shrine steps, up to the camp's gate, barred until the camp is built. There are no enemies yet.
3. Built: the Stalker, the jungle's first enemy (`docs/specs/stalker-spec.md`), perched on the canopy walk's east deck and the upper terraces' third bed.
4. Built: the Shrinekeeper Camp, through the shrine steps' gate swung open: a restored shrine with its bell, the Rest point; canvas shelters and herb racks, where the SHRINEKEEPER keeps a Supply Shop that sells Mourning Salts too; and a hymn of its own. Its way on to the root hollow stays walled.
5. Built: the Spore Beast (`docs/specs/spore-beast-spec.md`) in its lair under the lower terraces, dropped into through a hole in their floor, with a chest of three Glowroe at its far end; and the root hollow, off the camp's east end, three screens down a giant hollow root past a perched Stalker, its way east to Smuggler Inlet walled until the Inlet is planned.
6. Smuggler Inlet and the Pirate Fort, planned with their own grilling.
