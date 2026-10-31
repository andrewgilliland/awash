# Reefback Behavior Spec

## Purpose

The Reefback is the Waking Coast's Boss: a great sea-ape with a coral-crusted back, guarding the Warden's gate on the road to Tidefen. It tests what the coast taught: reading a Tell and moving before the attack it warns of, jumping what rolls along the floor, and that a Charged Attack bites through a Ward where a quick one glances off.

## Behavior

- It has 140 Health. It stands **dormant** at the arena's east end, taking no hits, until the Player comes within 80 pixels across the floor. Then it faces the Player, its Ward lights up, and after a 0.6-second beat the fight begins.
- It fights in turns: a **rest**, a **Tell**, then an **attack**. While it rests (1 second after each attack) it stomps toward a Player more than 24 pixels off at 20 pixels a second. A Tell plants it facing the Player for 0.8 seconds, flashing, holding its attack's pose, with a roar.
- It picks each attack by how far off the Player is, and never makes the same attack twice in a row. From more than 40 pixels off it chooses one of:
  - **Knuckle charge:** it gallops at the Player at 120 pixels a second for 0.75 seconds. Its touch costs 15 while it charges.
  - **Leap slam:** it leaps in a high arc for 0.8 seconds to where the Player stood as its Tell ended, untouchable and unstrikable in the air. It lands for 0.4 seconds: the landing costs 20 for its first part, and sends a short shockwave each way for 10.
  - **Reef throw:** it throws a chunk of reef from its hands in an arc to where the Player stands, 0.75 seconds in the air. It costs 15 if it hits, and shatters where it lands or hits.
- Up close it chooses one of:
  - **Lunge swipe:** it lunges at 90 pixels a second for 0.35 seconds, its swipe live in front of it for 15.
  - **Ground pound:** it strikes the floor for 0.5 seconds and a shockwave rolls each way for 1.8 seconds, costing 10. Jumping clears it.
- Touching it costs 10, except while it is dormant, airborne, staggered or defeated.
- The first time its Health is below half, it **beats its chest** instead of attacking, for 1.4 seconds, with no Tell: three shadows mark the floor, under the Player and 36 pixels either side, within the arena. After a second a rock falls on each mark, costing 10 to a Player standing there as it lands. From then on it **hurries**: each Tell lasts 0.55 seconds, and it stomps and charges a third faster.
- Its **Ward** is up whenever it is awake, shown as a pale flickering outline round whatever pose it shows. A quick Attack on the Ward clangs and does nothing. A Charged Attack, from either side, breaks it without costing Health, and the Reefback is **staggered** for 3 seconds: still, harmless to touch, and any sword hit costs it Health. After the Stagger the Ward returns, and after another 0.6-second beat it rests and attacks again.
- At 0 Health it fades over 1.5 seconds and is gone. Its defeat earns the Player 100 Experience and leaves nothing behind. The Run remembers it: it stays defeated through Room changes and the Player's own defeat, and only a new Run brings it back.
- Leaving through the west Exit resets the fight: back in the Room, it stands dormant at full Health.

## The Gate

- A column of rune light, 8 pixels wide, stands across the road at the arena's east edge, solid to the Player and the Reefback, between the Reefback and the Exit on to Tidefen.
- When the Reefback is defeated, the Run records it. The light waits 1.5 seconds for it to fade, dissolves over 0.8 seconds, and the way on is open. With the Reefback already defeated this Run, the Room opens with neither the Reefback nor the light.

## Boss Health bar

- While the Reefback is awake and not yet defeated, a bar 120 pixels wide along the bottom of the screen shows its Health, with `REEFBACK` above it in the compact font. It drains with a trail like the Player's Health bar, and hides once the Reefback falls.

## Sound

- A roar for every Tell; a run of heavy thuds as it charges, a rush of air as it swipes, a low boom as it pounds, air rushing up as it leaps and a heavy thud as it lands, rock tearing loose as it throws, drumming as it beats its chest; a bright clang off the Ward, shattering glass as the Ward breaks, a grunt when struck, and a last long breath as it falls.
- Rests and the Stagger are quiet. The Waking Coast theme plays on through the fight.
- Its sounds are positional `AudioStreamPlayer2D`s on the `SFX` bus under its `Sounds` node, made by `scripts/tools/make_sfx.py` into `assets/audio/sfx/reefback_*.wav`.

## Art

- `assets/sprites/enemies/reefback_1.png` holds its poses, one row of eight 48x48 frames facing right: roar, stand, walk, walk, walk, swipe, overhead, jump. Each state shows one: a charge or swipe's Tell holds the roar, a pound, leap or throw's the overhead; the stomp and the charge cycle the walk; a swipe, pound, landing and throw show the swipe; a leap shows the jump; the chest-beat alternates roar and stand; a Stagger shows the stand.
- `assets/sprites/enemies/reefback_props.png` holds four 16x16 frames: the reef chunk spinning (two), shattered, and a falling rock.
- Both sheets are plain placeholders drawn by `scripts/tools/make_reefback_placeholder.py`, to be drawn over in Aseprite keeping the layout. The Ward's outline is drawn by `assets/shaders/ward_outline.gdshader` round whatever is there.

## Placement

- **Warden's gate** (`waking_coast_7`): the Reefback at x 132 on the arena floor, the Gate at x 156; its rubble falls between x 40 and 148.

## Ownership

- `scripts/enemies/reefback_brain.gd` (the Reefback brain) owns the Behavior rules from one frame of facts: where the Player is, the share of Health left, whether the Ward just broke, and whether it is defeated. Its attack picker is swappable, so tests can choose its attacks.
- `scripts/enemies/reefback.gd` (the Reefback body) owns its Health, its Ward's answer to each hit, its movement and what each attack sends out, and shows the brain's state: its pose, facing, the leap's arc, the Ward's flicker, the Tell's flash, and which of its touch, swipe and landing hitboxes are live. It belongs to the `enemy` and `boss` groups.
- `scripts/enemies/shockwave.gd`, `scripts/enemies/reef_chunk.gd` and `scripts/enemies/rubble.gd` are the hitboxes it sends out: a shockwave rolling along the floor, a chunk arcing to its mark, a rock falling on its mark.
- `scripts/enemies/reefback_sounds.gd` (the Reefback sounds) owns which state changes make a sound; the body plays the Ward's and a hit's sounds itself.
- `scripts/core/boss_gate.gd` (the Gate) is the one place that records a Boss's defeat in the Run, and opens once it has.
- `scripts/ui/boss_bar.gd` (the Boss Health bar) is the Player's Health bar reading the fighting Boss's Health instead.
