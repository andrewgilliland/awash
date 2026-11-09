# Stalker Behavior Spec

## Purpose

The Stalker is the Low Canopy Jungle's first enemy (see `docs/enemies/stalker.md`): an altered jungle cat that waits on a high perch, marks where the Player stands with grasping roots, and pounces onto the mark. Nothing before it strikes from across a room, so it teaches the Player to read a mark on the ground as a warning, step off it, and punish the landing.

## Behavior

- It has 30 Health: three quick sword hits, or a Charged Attack and one quick hit.
- **Perched**, it crouches on its ledge, watching, harmless. It notices the Player when they are within 112 pixels sideways, no more than 16 pixels above its feet, and no more than 96 pixels below them.
- It then **marks** where the Player stands: roots burst from the ground under their feet for 0.6 seconds. The mark stays where it burst; the Player can step off it.
- It **leaps** onto the mark in an arc that takes 0.7 seconds, wherever the mark is. As it comes down, its claws, 16 by 10 pixels, are live, and landing on the Player costs them 12 Health.
- Landed, it **recovers** for 0.8 seconds, crouched and harmless: the opening.
- Then it **leaps back** to its perch in the same arc, harmless, and rests there for 1.2 seconds before it can notice the Player again.
- A sword hit costs it 10 Health, or 20 for a Charged Attack. Struck on its perch or as it marks, it flinches for 0.3 seconds and the mark is gone; struck as it recovers, it flinches, then leaps back. Struck in the air, it loses Health but flies on.
- At 0 Health it blinks out over 0.6 seconds, falling to the floor first if struck down in the air. Its defeat earns the Player 20 Experience and 4 Gold, every time, and has a 25% chance to leave a Brinecap where it fell.
- Like every enemy but a Boss, a defeated Stalker is back on its perch when its Room loads again.

## Sound

- It rustles as the roots burst, so the mark can be heard coming. It snarls as it pounces, its bark cracks when hit, and it yowls as it is defeated.
- Its sounds are positional `AudioStreamPlayer2D`s on the `SFX` bus under its `Sounds` node, made by `scripts/tools/make_sfx.py` into `assets/enemies/stalker/stalker_*.wav`.

## Placement

Each perches clear of every Entry.

- **`low_canopy_jungle_3`:** on the canopy walk's east deck, at x 280, over the bridge's far half.
- **`low_canopy_jungle_4`:** on the upper terraces' third bed, at x 136, over the ledges below it.

## Ownership

- `scripts/enemies/stalker_brain.gd` (the Stalker brain) owns the Behavior rules from one frame of facts: where it and the Player stand, whether it stands on a floor, and whether a hit landed or defeated it.
- `scripts/enemies/stalker.gd` (the Stalker body) owns its Health and movement, reads the Player through the `player` group, and shows the brain's state: its animation, whether its claws are live, and the roots at the mark.
- `scripts/enemies/stalker_sounds.gd` (the Stalker sounds) owns which state changes make a sound.
- Its 24x16 frames and the roots' 16x16 frames are drawn new in `assets/enemies/stalker/stalker_1.aseprite`, in the jungle mockup's palette: no art pack holds it.
