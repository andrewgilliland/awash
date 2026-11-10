# Rusk Behavior Spec

## Purpose

Rusk is the Low Canopy Jungle's Boss (see `docs/enemies/rusk.md` and `docs/characters/rusk.md`): Ilyr's enforcer, a broad warrior in scarred hide and scavenged plate with an oversized maul etched with a single arcane brand. He ambushes Vael at the root's mouth, where the jungle meets Smuggler Inlet, and traps him there with branded roots until he is beaten. He tests two kinds of jump: over him as he charges, and into the air as his maul shakes the floor. He does not die: beaten, he retreats, to return at Stormwatch Tower.

## Behavior

- He has 200 Health: twenty quick sword hits, or ten Charged Attacks. He is Large, and never flinches.
- **Dormant**, he stands at his post on the arena's east side, facing west, taking no hits and harming no one. He wakes when the Player comes within 88 pixels across, 32 pixels into the arena.
- **Speaking:** he turns to the Player and says his line, and the Player stands still until the box closes:
  - RUSK: "Vael. You're a dead man."
  - RUSK: "You should have stayed beneath the waves."
- **Summoning:** as the box closes he drives his maul into the floor and roars, its brand flaring, and the branded roots burst up across the arena's edges. He holds it 0.6 seconds, harmless to touch, then after a 0.6-second beat makes his first move.
- He fights in turns: a move, then a 1.0-second **rest**. At the end of each rest he faces the Player and picks his move by where they stand:
  - **Armored charge**, when the Player is more than 48 pixels across from him:
    - **Tell:** he lowers his shoulder and stamps for 0.6 seconds.
    - **Charge:** he runs at 180 pixels a second until he meets a wall, costing the Player 15 on contact. His plate turns aside quick hits on his front as he charges: they clang and cost him nothing. A Charged Attack, or any hit from behind, lands.
    - **Dazed:** meeting the wall shakes the screen, and he stands dazed for 1.2 seconds, harmless to touch: the opening.
  - **Ground-shaking blow**, when the Player is within 48 pixels across:
    - **Wind-up:** he raises the maul for 0.7 seconds.
    - **Slam:** the maul lands in front of him, a blow 32 pixels long that costs the Player 20, live for 0.3 seconds.
    - **Quake:** as it lands the floor shakes the screen and strikes a Player standing anywhere on the arena's floor for 6, pushing them away from him. A Player in the air is untouched.
- Touching him costs the Player 10, or 15 as he charges, except while he is dormant, speaking, summoning, dazed, kneeling or leaping.
- Below half his Health he **hurries**: each tell and wind-up lasts 0.4 seconds, and his brand burns brighter. A charge that meets a wall goes straight into a wind-up and slam, with no daze, and then a second charge back the other way, which is dazed as normal.
- A sword hit costs him 10 Health, or 20 for a Charged Attack, whenever he fights: from the roots rising until his kneel.

## His retreat

- At 0 Health he **kneels**, and says:
  - RUSK: "Ilyr pays his debts. So do I."
  - RUSK: "This isn't over."
- His defeat earns the Player 150 Experience and leaves nothing behind. The Run remembers it as `rusk_jungle`, so his Stormwatch fight is remembered apart.
- When the box closes he **leaps** away east, up and off the clifftop's edge over the roots, and is gone. As he leaps, the roots wither and sink over 1 second.
- With him already beaten this Run, the root's mouth opens with neither Rusk nor roots.
- If the Player is defeated in the fight, they wake at the Rest point last rung as after any defeat, and Rusk is back at his post at full Health.

## The branded roots

- Thick roots glowing blue with his maul's brand, 8 pixels wide, burst up across the arena's west edge, at the foot of the root's mouth, and its east edge, rising over 0.4 seconds. Solid to the Player and to him, they shut the Player in with him until he leaps away.
- The camera holds on the arena from his first word until he leaps away.
- The way east to Smuggler Inlet stays walled behind the east roots until the Inlet is built.

## Boss Health bar

- From the roots rising until he kneels, the Boss Health bar shows his Health with `RUSK` above it.

## Music

- The jungle's theme falls silent as he speaks. His own theme, `rusk_theme`, a driving minor march faster than the jungle's with heavy drums, plays from the roots rising until his leap, when the jungle's theme returns. It is made by `scripts/tools/make_music.py` into `assets/enemies/rusk/rusk_theme.wav`, for his later fight to share.

## Sound

- He roars as the roots rise, stamps in each tell, crashes into the wall, whooshes the maul up in each wind-up, booms with each slam, clangs off his plate, grunts when struck and cries out as he leaps. The roots creak as they rise and as they wither.
- His sounds are positional `AudioStreamPlayer2D`s on the `SFX` bus under his `Sounds` node, the roots' under theirs, made by `scripts/tools/make_sfx.py` into `assets/enemies/rusk/rusk_*.wav`.

## Placement

- **The root's mouth** (`low_canopy_jungle_8`, 2x1), east off the root hollow's foot. Its west screen is the way out of the root, a step down into daylight; its east screen is the arena, flat from edge to edge at y 112. Rusk at x 280; the roots at x 164 and x 316. The root hollow's foot opens east into it; its Pirate stands at x 136, clear of the Player coming back.

## Ownership

- `scripts/enemies/rusk_brain.gd` (the Rusk brain) owns the Behavior rules from one frame of facts: where the Player is, the share of Health left, whether his line was read, whether his charge met a wall, and whether he is defeated.
- `scripts/enemies/rusk.gd` (the Rusk body) owns his Health, his plate's answer to each hit, his movement and leap, his words, and shows the brain's state: his pose, facing, the brand's glow, his touch, the maul's blow and the quake. It belongs to the `enemy` and `boss` groups.
- `scripts/enemies/rusk_sounds.gd` (the Rusk sounds) owns which state changes make a sound; the body plays a hit's sounds itself.
- `scripts/core/boss_arena.gd` (the Boss arena) records his defeat in the Run, raises and withers the roots, holds the camera on the arena and plays his theme.
- `scripts/world/branded_roots.gd` (the branded roots) is a wall that rises and withers.
- `assets/enemies/rusk/rusk_1.aseprite` holds his 48x48 frames facing right, in two rows: stand, summon, tell, charge twice, dazed, wind-up, slam, kneel and leap, then the brand's glow alone on each. `assets/enemies/rusk/branded_roots.aseprite` holds the roots' 8x112 column.
