# Spore Beast Behavior Spec

## Purpose

The Spore Beast is the Low Canopy Jungle's second enemy (see `docs/enemies/spore-beast.md`): a swollen garden beast that lumbers after the Player and vents toxic spores whenever it is struck. It is the first enemy too big to flinch, so it teaches the Player to strike and step back, and to wait out a cloud before striking again.

## Behavior

- It has 60 Health: six quick sword hits, or three Charged Attacks. It is Large, and never flinches.
- **Idle**, it stands still. It notices the Player when they are within 160 pixels sideways and 48 pixels up or down.
- It then **lumbers** toward them at 24 pixels a second. Touching it costs the Player 10 Health.
- Every hit it takes **vents** a cloud of spores around it, 24 pixels out, and it stands puffed for 0.4 seconds before it lumbers on. The cloud stays where it burst for 1.5 seconds. A Player inside it when it bursts, or stepping into it, loses 8 Health. A Sword Beam reaches the Spore Beast from outside the cloud.
- At 0 Health it blinks out over 0.6 seconds and its last cloud bursts. Its defeat earns the Player 40 Experience and 8 Gold, every time, and has a 25% chance to leave a Brinecap where it fell.
- Like every enemy but a Boss, a defeated Spore Beast is back in its lair when the Room loads again.

## Sound

- It snorts when it notices the Player, hisses as each cloud bursts, and groans as it is defeated.
- Its sounds are positional `AudioStreamPlayer2D`s on the `SFX` bus under its `Sounds` node, made by `scripts/tools/make_sfx.py` into `assets/enemies/spore_beast/spore_beast_*.wav`.

## Placement

- **`low_canopy_jungle_5`:** the Spore Beast's lair, under the lower terraces, in its den on the east screen, at x 248, between the Player's way in and the lair's chest.

## Ownership

- `scripts/enemies/spore_beast_brain.gd` (the Spore Beast brain) owns the Behavior rules from one frame of facts: where it and the Player stand, and whether a hit landed or defeated it.
- `scripts/enemies/spore_beast.gd` (the Spore Beast body) owns its Health and movement, reads the Player through the `player` group, shows the brain's state, keeps its hide harmful to touch, and lets each cloud burst where the brain vents one.
- `scripts/enemies/spore_cloud.gd` (a spore cloud) owns a cloud's life: it strikes for 8 as it bursts or as the Player steps in, and fades after 1.5 seconds.
- `scripts/enemies/spore_beast_sounds.gd` (the Spore Beast sounds) owns which state changes make a sound.
- Its 32x24 frames and the cloud's 48x48 frames are drawn new in `assets/enemies/spore_beast/spore_beast_1.aseprite`, in the jungle mockup's palette: no art pack holds it.
