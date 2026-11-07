# Silt Crab Behavior Spec

## Purpose

The Silt Crab is the Undertow's second enemy of its own (see `docs/enemies/silt-crab.md`): a pale cave crab clinging to the drowned temple's low ceilings. Nothing else in the game strikes from above, so it teaches the Player to watch the ceiling, read a falling trickle of silt as a warning, and step back from the drop to punish the landing.

## Behavior

- It has 20 Health: one Charged Attack, or two quick sword hits.
- **Clinging**, it hangs still from a ceiling, its feet against it, harmless. It notices the Player when they are below it and within 24 pixels sideways.
- It then **shakes** for 0.5 seconds: a thin trickle of silt falls beneath it. Once it shakes, the drop always follows, even if the Player steps away.
- It **drops** under gravity. Its claws, 14 by 10 pixels, are live as it falls, and landing on the Player costs them 15 Health.
- Landed, it lies **stunned** on its back for 1 second, harmless: the easy opening.
- Then it rights itself and **scuttles** sideways toward the Player at 40 pixels a second. Touching it costs the Player 10 Health.
- A sword hit costs it 10 Health, or 20 for a Charged Attack, and it flinches for 0.3 seconds, harmless, then scuttles on.
- A hit while it still clings or shakes **knocks it down**: it costs Health as any hit does, it falls with its claws harmless, and it lands stunned. On the Undertow's 80-pixel ceilings neither a Sword Beam, which flies level, nor a Bomb's lob reaches it; under the wreck's lower ledge a jumping Attack can.
- At 0 Health it blinks out over 0.6 seconds, falling to the floor first if struck down in the air. Its defeat earns the Player 15 Experience and 3 Gold, every time, and has a 25% chance to leave a Brinecap where it fell.
- Like every enemy but a Boss, a defeated Silt Crab is back on its ceiling when its Room loads again.

## Sound

- It skitters dryly as it shakes, so the drop can be heard coming. It thuds as it lands, its shell cracks when hit, and its shell splits and its legs rattle still when defeated.
- Its sounds are positional `AudioStreamPlayer2D`s on the `SFX` bus under its `Sounds` node, made by `scripts/tools/make_sfx.py` into `assets/enemies/silt_crab/silt_crab_*.wav`.

## Placement

Each hangs clear of every Entry and not over a Cache.

- **`undertow_2`:** from the ceiling over the temple hall's upper floor, at x 88.
- **`undertow_3`:** from the colonnade's ceiling, at x 96, west of the Wraith's haunt.
- **`undertow_5`:** under the low ledge over the wreck's floor, at x 168.

## Ownership

- `scripts/enemies/silt_crab_brain.gd` (the Silt Crab brain) owns the Behavior rules from one frame of facts: where the Player is, whether it stands on a floor, and whether a hit landed or defeated it.
- `scripts/enemies/silt_crab.gd` (the Silt Crab body) owns its Health and movement, reads the Player through the `player` group, and shows the brain's state: its animation, whether its claws are live and for how much, and whether silt falls.
- `scripts/enemies/silt_crab_sounds.gd` (the Silt Crab sounds) owns which state changes make a sound.
- Its 16x16 frames are drawn new in `assets/enemies/silt_crab/silt_crab_1.aseprite`: no art pack holds a crab.
