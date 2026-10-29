# Wraith Behavior Spec

## Purpose

The Wraith is the Waking Coast's third enemy (see `docs/enemies/wraith.md`): a spectral oathkeeper that haunts the tunnels under the coast. It teaches the Player to watch rather than swing: the sword passes through it until it lashes out, and only the rune anchor it shows afterwards can be struck.

## Behavior

- It has 30 Health, three quick sword hits or a Charged Attack and a quick one. It floats through the world without colliding, see-through while **phased**, and bobs 2 pixels up and down around the height it is placed at.
- Phased, it **drifts** across its haunt at 12 pixels a second, turning at the ends. When the Player is within 80 pixels sideways, it drifts toward the Player at 22 pixels a second instead, never leaving its haunt.
- When the Player is within 24 pixels sideways and 24 up or down, it turns to face the Player and **manifests** for 0.5 seconds: it turns solid and its rune anchor starts to glow.
- It then **lashes** for 0.25 seconds. Its claw hitbox, 20 by 16 pixels, 14 pixels in front of it, is live, and costs the Player 15 Health.
- Then its anchor is **exposed** for 1 second: solid and still, glowing. Only now can the sword hit it.
- A sword hit costs it 10 Health, or 20 for a Charged Attack, pushes it away at 60 pixels a second, slowing over 0.35 seconds, and it phases again. One opening takes one hit.
- After exposing or being hurt it stays phased for at least 1 second before it can manifest again.
- At 0 Health it stops, blinks for 0.6 seconds, and is gone.
- It floats about 16 pixels above the floor it haunts, where a swing from the ground reaches its anchor and its lash reaches the Player.

## Sound

- It wails as it manifests, rising over the whole manifest, so the lash can be heard coming. Its lash whooshes, it cracks like stone when hurt, and it sighs away into the water when defeated.
- Drifting and being exposed are quiet.
- Its sounds are positional `AudioStreamPlayer2D`s on the `SFX` bus under its `Sounds` node. They fade out 240 pixels from the Player's camera.
- They are chiptune effects made by `scripts/tools/make_sfx.py` into `assets/audio/sfx/wraith_*.wav`.

## Placement

- **Undertow:** one Wraith in the tall stretch of tunnel west of the east pool, haunting between x 448 and 528.

## Ownership

- `scripts/enemies/wraith_brain.gd` (the Wraith brain) owns the Behavior rules from one frame of facts: its position, where the Player is, and whether a hit landed or defeated it.
- `scripts/enemies/wraith.gd` (the Wraith body) owns its Health and movement, reads the Player through the `player` group, and shows the brain's state: its animation, facing, how solid it looks, whether the lash is live and whether its anchor can be hit.
- `scripts/enemies/wraith_sounds.gd` (the Wraith sounds) owns which state changes make a sound. The body plays one whenever the brain's state changes.
- `assets/sprites/enemies/wraith_1.aseprite` holds its 32x32 frames, facing right: two drift, two manifest, two lash, exposed and hurt.
