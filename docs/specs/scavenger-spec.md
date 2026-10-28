# Scavenger Behavior Spec

## Purpose

The Scavenger is the Waking Coast's first enemy (see `docs/enemies/scavenger.md`): a fish-man that guards a tidal pool and teaches the Player to read a wind-up and strike back.

## Behavior

- It has 3 Health and patrols its stretch of shallows at 20 pixels a second, turning at the ends of its patrol.
- When the Player is within 40 pixels sideways and 20 pixels up or down, it stops, turns to face the Player, and winds up for 0.45 seconds, drawing its spear back.
- It then lunges at 150 pixels a second for 0.2 seconds with its spear hitbox live, 10 pixels in front of it, and recovers standing still for 0.6 seconds before patrolling again.
- A sword hit costs it 1 Health, ends any wind-up or lunge, turns it toward the Player and pushes it away at 90 pixels a second, slowing over 0.35 seconds. It is invulnerable for 0.3 seconds after a hit, so one swing lands once.
- At 0 Health it stops, blinks for 0.6 seconds, and is gone.

## Ownership

- `scripts/enemies/scavenger_brain.gd` (the Scavenger brain) owns the Behavior rules from one frame of facts: its position, where the Player is, and whether a hit landed or defeated it.
- `scripts/enemies/scavenger.gd` (the Scavenger body) owns its Health, gravity and movement, reads the Player through the `player` group, and shows the brain's state: its animation, facing and whether the spear is live.
- `assets/sprites/enemies/scavenger_1.aseprite` holds its frames: two patrol strides, wind-up, lunge and hurt.
