# Storm Wisp Behavior Spec

## Purpose

The Storm Wisp is the Waking Coast's second enemy (see `docs/enemies/storm-wisp.md`): a knot of mist and lightning that rides the wind over exposed heights. It teaches the Player to read a crackle, keep clear of the arc, and strike in the quiet after it.

## Behavior

- It has 2 Health, flies through the world without colliding, and drifts across its stretch of sky at 16 pixels a second. It turns at the ends, and bobs 4 pixels up and down around the height it is placed at.
- When the Player comes within 32 pixels, it stops and **crackles** for 0.7 seconds.
- It then **arcs** for 0.3 seconds. Its lightning hitbox, a circle 15 pixels across from its centre, is live, and costs the Player 1 Health.
- It **rests**, dim and still, for 0.9 seconds, then drifts again. Resting is the moment to strike.
- A sword hit costs it 1 Health, ends any crackle or arc, and pushes it away at 70 pixels a second, slowing over 0.35 seconds. It is invulnerable for 0.3 seconds after a hit, so one swing lands once.
- At 0 Health it stops, blinks for 0.5 seconds, and is gone.
- It hovers about 14 pixels above the ground it guards, where a swing from the ground reaches it and its arc reaches the Player.

## Sound

- It crackles with static that thickens over the whole crackle, so the arc can be heard coming. Its arc snaps, it fizzes when hurt, and it hisses away on the wind when defeated.
- Resting and drifting are quiet.
- Its sounds are positional `AudioStreamPlayer2D`s on the `SFX` bus under its `Sounds` node. They fade out 240 pixels from the Player's camera.
- They are chiptune effects made by `scripts/tools/make_sfx.py` into `assets/audio/sfx/storm_wisp_*.wav`.

## Placement

- **Rune road:** one Wisp over the heights at the road's end, drifting between x 210 and 300.

## Ownership

- `scripts/enemies/storm_wisp_brain.gd` (the Storm Wisp brain) owns the Behavior rules from one frame of facts: its position, where the Player is, and whether a hit landed or defeated it.
- `scripts/enemies/storm_wisp.gd` (the Storm Wisp body) owns its Health and movement, reads the Player through the `player` group, and shows the brain's state: its animation and whether the arc is live.
- `scripts/enemies/storm_wisp_sounds.gd` (the Storm Wisp sounds) owns which state changes make a sound. The body plays one whenever the brain's state changes.
- `assets/sprites/enemies/storm_wisp_1.aseprite` holds its 32x32 frames: two drift, two crackle, two arc, rest and hurt.
