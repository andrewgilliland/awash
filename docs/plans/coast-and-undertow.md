# Plan: The Waking Coast, Tidefen and the Undertow

Agreed 2026-11-02, from three throwaway layouts drawn with the Map's own code. The layout lives in the World as its Plan; draw it with `./scripts/tools/draw_map.sh --plan`.

## Decisions

- The coast climbs up and right: the beach, the palm shore, new tide pools, the salt cliffs, new ledges up to the cliff tops, then the wreck graveyard up on the tops. A new broken stair comes down to the jungle trail, the Warden's gate and Tidefen, back at sea level.
- Tidefen stays the Waking Coast's Safe spoke, coloured with the coast on the Map.
- The Warden stays the last Room before Tidefen.
- The graveyard's sinkhole goes. The sea cave sits under the cliffs and is reached only from the cliffs' foot.
- The Undertow becomes its own Region, beneath the cliffs and the graveyard, with its own Map name and colour. It has no Safe spoke of its own and leans on Tidefen.
- The Undertow is off the Main path, a Branch the Player comes back to later.
- Its way in is a Drop down Tidefen's well, hidden until a point in the story. There is no climbing back up.
- Its way home is a Shortcut through the sea cave's wall, opened from the Undertow side. From the sea cave it stays shut.
- A Boss waits at the Undertow's far west end, named and designed later.
- The undertow tunnel Room (`waking_coast_9`) moves into the Undertow.

## How the Plan is held

- Each Room's World record keeps what is true today. Where the agreed layout differs, the record carries a `plan` with its planned cell, Region, Exits and markers.
- Planned Rooms have no scene: four on the coast (`waking_coast_10` to `13`) and eight in the Undertow (`undertow_1` to `8`).
- The game plays the World as it is. A Room's plan folds into its record when it is moved or built.
- `tests/world_plan_tests.gd` keeps the Plan whole: no Rooms overlapping, Exits meeting (but Drops), the climb and descent, and the Undertow's two ways in.

## Order of work

Each step gets its own grilling and PR.

1. Built: move the built coast Rooms to their planned places, with the new coast Rooms built between them as they're needed. That covers the graveyard on the cliff tops, the stair down, and the trail, the Warden and Tidefen at sea level.
2. Built: the sea cave under the cliffs, and the sinkhole removed. The sea cave is reached down a hole under the cliffs' foot and climbed out of up two landings.
3. Built: the Undertow as a Region, drawn from the Mucho Pixels Underwater pack: its theme, Background and tile sheets, with the undertow tunnel moved into it.
4. Built but for the Boss: the Undertow's Rooms (`undertow_1` to `undertow_7`), its Shortcut through the sea cave (a cracked wall a Charged Attack breaks from the Undertow side), and the first Cache, in a wreck at its dead end. Its Boss and the arena (`undertow_8`) behind the lake's sealed temple door come with their own grilling.
5. The story beat that opens Tidefen's well.
