# Nameless Warden Behavior Spec

## Purpose

The Nameless Warden is the Waking Coast's Boss (see `docs/enemies/nameless-warden.md`): an armored spirit with a blank stone mask and a salt-crusted shield, guarding the Warden's gate on the road to Tidefen. It tests what the coast taught: jumping what comes along the floor, keeping clear of a telegraphed rush, and that a Charged Attack bites through a Ward where a quick one glances off. Guarding and Throwing Knives join the fight once the Player has them.

## Behavior

- It has 120 Health. It stands **dormant** at the arena's east end, taking no hits, until the Player comes within 80 pixels across the floor. Then it faces the Player, its Ward lights up, and after a 0.6-second beat the fight begins.
- It fights in turns: a **wind-up**, a move, then a 1.5-second **rest**. Each wind-up lasts 1 second, its shield blinking bright, and turns it to face the Player.
- Its moves alternate, starting with the bash. The **shield bash** charges toward the Player at 120 pixels a second for 0.5 seconds, and costs the Player 15. The **slam** strikes the floor for 0.3 seconds and sends a **shockwave** rolling each way along it.
- A shockwave starts 12 pixels to either side of the Warden and rolls at 90 pixels a second for 1.8 seconds, then fades. It is 12 by 6 pixels on the floor, costs the Player 10, and jumping clears it.
- Touching the Warden costs the Player 10, except while it is dormant, staggered or defeated.
- Below half its Health it **hurries**: each wind-up lasts 0.7 seconds, and each slam strikes twice in a row, a shockwave pair each time.
- Its **Ward** is up whenever it is awake, shown as a pale flickering outline. A quick Attack on the Ward clangs and does nothing. A Charged Attack, from either side, breaks it without costing Health, and the Warden is **staggered** for 3 seconds: still, slumped, harmless to touch, and any sword hit costs it Health, 10 for a quick one or 20 for a Charged one. After the Stagger the Ward returns, and after another 0.6-second beat it winds up again.
- At 0 Health it kneels and fades over 1.5 seconds, and is gone. Its defeat earns the Player 100 Experience and leaves nothing behind. The Run remembers it: it stays defeated through Room changes and the Player's own defeat, and only a new Run brings it back.
- Leaving through the west Exit resets the fight: back in the Room, it stands dormant at full Health.

## The Gate

- A column of rune light, 8 pixels wide, stands across the road at the arena's east edge, solid to the Player and the Warden, between the Warden and the Exit on to Tidefen.
- When the Warden is defeated, the Run records it. The light waits 1.5 seconds for the Warden to fade, dissolves over 0.8 seconds, and the way on is open. With the Warden already defeated this Run, the Room opens with neither the Warden nor the light.

## Boss Health bar

- While the Warden is awake and not yet defeated, a bar 120 pixels wide along the bottom of the screen shows its Health, with `NAMELESS WARDEN` above it in the compact font. It drains with a trail like the Player's Health bar, and hides once the Warden falls.

## Sound

- A deep swell as it winds up, a heavy rush as it bashes, a low boom with each slam, a bright clang off the Ward, shattering glass and a falling chime as the Ward breaks, stone and iron when struck, and a falling knell as it kneels.
- Waking, resting and the Stagger are quiet. The Waking Coast theme plays on through the fight.
- Its sounds are positional `AudioStreamPlayer2D`s on the `SFX` bus under its `Sounds` node, made by `scripts/tools/make_sfx.py` into `assets/audio/sfx/warden_*.wav`.

## Placement

- **Warden's gate** (`waking_coast_7`): the Warden at x 136 on the arena floor, the Gate at x 156.

## Ownership

- `scripts/enemies/warden_brain.gd` (the Warden brain) owns the Behavior rules from one frame of facts: where the Player is, the share of Health left, whether the Ward just broke, and whether it is defeated.
- `scripts/enemies/nameless_warden.gd` (the Warden body) owns its Health, its Ward's answer to each hit, its movement and the shockwaves it sends, and shows the brain's state: its pose, facing, the Ward's flicker, the wind-up's blink and whether its touch harms. It belongs to the `enemy` and `boss` groups.
- `scripts/enemies/shockwave.gd` (a shockwave) is a hitbox that rolls along the floor and fades.
- `scripts/enemies/warden_sounds.gd` (the Warden sounds) owns which state changes make a sound; the body plays the Ward's and a hit's sounds itself.
- `scripts/core/boss_gate.gd` (the Gate) is the one place that records a Boss's defeat in the Run, and opens once it has.
- `scripts/ui/boss_bar.gd` (the Boss Health bar) is the Player's Health bar reading the fighting Boss's Health instead.
- `assets/sprites/enemies/nameless_warden_1.aseprite` holds its 32x32 frames facing right, in two rows: stand, wind-up, bash, slam, stagger and kneel, then the Ward's outline around each. `assets/sprites/enemies/shockwave.aseprite` holds the shockwave's two 16x8 frames.
