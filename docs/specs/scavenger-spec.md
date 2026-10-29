# Scavenger Behavior Spec

## Purpose

The Scavenger is the Waking Coast's first enemy (see `docs/enemies/scavenger.md`): a fish-man that guards a tidal pool and teaches the Player to read a wind-up and strike back.

## Behavior

- It has 30 Health, three quick sword hits or a Charged Attack and a quick one, and patrols its stretch of shallows at 20 pixels a second, turning at the ends of its patrol.
- When the Player is within 40 pixels sideways and 20 pixels up or down, it stops, turns to face the Player, and winds up for 0.45 seconds, drawing its spear back.
- It then lunges at 150 pixels a second for 0.2 seconds with its spear hitbox live, 10 pixels in front of it, and recovers standing still for 0.6 seconds before patrolling again.
- A sword hit costs it 10 Health, or 20 for a Charged Attack, ends any wind-up or lunge, turns it toward the Player and pushes it away at 90 pixels a second, slowing over 0.35 seconds. It is invulnerable for 0.3 seconds after a hit, so one swing lands once.
- At 0 Health it stops, blinks for 0.6 seconds, and is gone. Its defeat earns the Player 10 Experience, every time.

## Sound

- It growls as it winds up, rising over the whole wind-up so the lunge can be heard coming; its spear sounds as it lunges; it croaks when hurt; and it burbles back into the pool when defeated.
- Recovering and returning to patrol are quiet.
- Its sounds are positional `AudioStreamPlayer2D`s on the `SFX` bus under its `Sounds` node, fading out 240 pixels from the Player's camera, so they pan with where it stands.
- They are chiptune effects made by `scripts/tools/make_sfx.py` into `assets/audio/sfx/scavenger_*.wav`.

## Ownership

- `scripts/enemies/scavenger_brain.gd` (the Scavenger brain) owns the Behavior rules from one frame of facts: its position, where the Player is, and whether a hit landed or defeated it.
- `scripts/enemies/scavenger.gd` (the Scavenger body) owns its Health, gravity and movement, reads the Player through the `player` group, and shows the brain's state: its animation, facing and whether the spear is live.
- `scripts/enemies/scavenger_sounds.gd` (the Scavenger sounds) owns which state changes make a sound; the body plays one whenever the brain's state changes.
- `assets/sprites/enemies/scavenger_1.aseprite` holds its frames: two patrol strides, wind-up, lunge and hurt.
