# Lurelight Behavior Spec

## Purpose

The Lurelight is the Undertow's first enemy (see `docs/enemies/lurelight.md`): a fish lurking under the dark water of its pools, its lure a rune-blue light mimicking the rune light that sank with the drowned temple. It is the lights beneath the waves that drove Tidefen's fishers from deep water. It teaches the Player to read the water: the pool itself is the danger, and the opening comes after the strike, not before.

## Behavior

- It has 20 Health: one Charged Attack, or two quick sword hits across two openings. It lives in one pool, under the surface, between the pool's edges set where it is placed. Only its lure shows, bobbing on the water.
- **Hidden**, its lure cannot be hit: the sword passes through. When the Player is within 48 pixels sideways and 40 up or down of the lure, it drifts toward the Player at 16 pixels a second, stopping at its pool's edges. Out of sight, it waits where it is.
- When the Player is within 16 pixels sideways and low enough for the Snap to reach, on the ground or in the air, it **dims** for 0.6 seconds: its lure goes out and bubbles rise where its jaws will break the surface. It stops drifting. Once it dims, the Snap and the stranding always follow, even if the Player steps away.
- It then **snaps** for 0.25 seconds: its jaws burst straight up out of the water. Its jaw hitbox, 16 by 24 pixels, rising from the surface above it, is live, and costs the Player 15 Health. It catches a Player wading or hopping; a full jump clears it at its height. The Player is knocked away from the jaws' centre, or the way they face if dead centre.
- Then it lies **stranded** at the surface for 1 second, its head out of the water at the height of a swing from the bank or from in the pool. Only now can the sword hit it.
- A sword hit costs it 10 Health, or 20 for a Charged Attack, and it **sinks** at once. One opening takes one hit.
- After stranding or being hit, it sinks and its lure stays dark for 1.2 seconds before it lights again and it is Hidden.
- Touching its body does no harm: only its jaws do.
- At 0 Health it floats belly-up at the surface, its lure dark, then sinks out of sight. Its defeat earns the Player 15 Experience, every time, and has a 20% chance to leave a Brinecap resting on the water where it fell.

## Sound

- It gulps low as it dims, so the Snap can be heard coming. Its Snap splashes and its jaws clack, it squeals when hit, and it gurgles as it sinks, defeated.
- Hidden and drifting, it is quiet.
- Its sounds are positional `AudioStreamPlayer2D`s on the `SFX` bus under its `Sounds` node, like the other enemies'.

## Placement

- **`undertow_4`:** one Lurelight in each of its two pools, between x 160 and 208, and x 240 and 288.
- **`undertow_7`:** one in each of the lake's two long stretches, between x 64 and 160, and x 208 and 320. The short stretch at the lake's east end, the first the Player wades in from the east Entry, stays empty.

## Ownership

- `scripts/enemies/lurelight_brain.gd` (the Lurelight brain) owns the Behavior rules from one frame of facts: its position, where the Player is, and whether a hit landed or defeated it.
- `scripts/enemies/lurelight.gd` (the Lurelight body) owns its Health and drift, reads the Player through the `player` group, and shows the brain's state: its animation, whether its lure is lit, whether its jaws are live and whether it can be hit.
- `scripts/enemies/lurelight_sounds.gd` (the Lurelight sounds) owns which state changes make a sound.
- Its 32x32 frames are drawn new: no art pack holds a fish. The dim's bubbles come from the Underwater pack's `air_bubbles`.
