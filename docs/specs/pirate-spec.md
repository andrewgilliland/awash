# Pirate Behavior Spec

## Purpose

The Pirate is the Low Canopy Jungle's corsair (see `docs/enemies/pirate.md`): a skirmisher from the Pirate Fort who holds a post, rushes the Player with a cutlass up close, and lobs clay bombs at them from afar. It is the first enemy that picks its attack by where the Player stands, so it teaches the Player to read the range: close in and it rushes, hang back or climb and it throws.

## Behavior

- It has 40 Health: four quick sword hits, or two Charged Attacks.
- **On guard**, it stands at its post, harmless but for touch: touching it costs the Player 6 Health. Its post is where it first stands. It notices the Player when they are within 144 pixels across and 96 pixels above or below its feet, and whistles the first time it does; it whistles again only once the Player has left its notice.
- When it notices the Player it faces them and picks an attack by where they stand:
  - **Cutlass rush**, when the Player is on its level, no more than 16 pixels above or below its feet, and within 64 pixels across:
    - **Tell:** it raises its cutlass and stamps for 0.4 seconds.
    - **Rush:** it dashes 0.35 seconds at 160 pixels a second along its floor, its cutlass live in front of it, 16 by 10 pixels, costing the Player 10. It stops short at a ledge's edge.
    - **Winded:** it stands 0.7 seconds, harmless but for touch: the opening.
  - **Bomb**, otherwise:
    - **Wind-up:** it draws back its arm for 0.4 seconds.
    - **Throw:** it lobs a Pirate bomb that lands where the Player stands as it lets go, 0.5 seconds later, its arc low enough to pass under a ledge two jumps up.
    - **Reload:** it takes 1.0 seconds to ready the next.
- It never chases. Back on guard away from its post, it walks back to it at 32 pixels a second, still watching.
- A sword hit costs it 10 Health, or 20 for a Charged Attack. Struck on guard, in its tell, wind-up, winded or reloading, it flinches for 0.3 seconds and that attack is lost. Struck mid-rush it loses Health but rushes on: the rush is committed, so the Player dodges or jumps it.
- At 0 Health it blinks out over 0.6 seconds. Its defeat earns the Player 30 Experience and 10 Gold, every time, and has a 25% chance to leave a Bomb where it fell.
- Like every enemy but a Boss, a defeated Pirate is back at its post when its Room loads again.

## The Pirate bomb

- A clay bomb like the Player's, drawn and heard the same. It flies its arc, stops where it first lands and sits with its fuse sputtering, then bursts 1.2 seconds after it was thrown.
- Its burst strikes the Player within 20 pixels for 12, as it bursts. It never strikes an enemy, nor breaks a Breakable wall, and the Player's sword passes through it.

## Sound

- It whistles as it first notices the Player, its cutlass swishes as it rushes, it grunts when hit and cries out as it is defeated. A Pirate bomb sputters and bursts with the Player's Bomb's sounds.
- Its sounds are positional `AudioStreamPlayer2D`s on the `SFX` bus under its `Sounds` node, made by `scripts/tools/make_sfx.py` into `assets/enemies/pirate/pirate_*.wav`.

## Placement

Each stands clear of every Entry.

- **`low_canopy_jungle_7`:** at the root hollow's foot, at x 136, on guard before the way east into the root's mouth, clear of the Player coming back through it. It throws at the Player coming down the last ledges and across the floor; the low ledge at the foot's west end, two rows up, is cover its bombs cannot reach under.
- More stand in Smuggler Inlet and the Pirate Fort, on guarded ledges, once those are planned.

## Ownership

- `scripts/enemies/pirate_brain.gd` (the Pirate brain) owns the Behavior rules from one frame of facts: where it and the Player stand, whether it stands on a floor and has floor ahead, and whether a hit landed or defeated it.
- `scripts/enemies/pirate.gd` (the Pirate body) owns its Health and movement, reads the Player through the `player` group, and shows the brain's state: its animation, whether its cutlass is live, and the Pirate bombs it throws.
- `scripts/enemies/pirate_bomb.gd` (the Pirate bomb) owns a thrown bomb's flight, fuse and burst.
- `scripts/enemies/pirate_sounds.gd` (the Pirate sounds) owns which state changes make a sound.
- Its 24x24 frames are drawn new in `assets/enemies/pirate/pirate_1.aseprite`, in the jungle mockup's palette: no art pack holds it.
