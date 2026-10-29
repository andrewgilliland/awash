# Player Behavior Spec

## Purpose

This spec defines the minimal player baseline while player behavior is rebuilt.

## Controls

- `move_left`: move horizontally to the left.
- `move_right`: move horizontally to the right.
- `jump`: jump while grounded.
- `melee_attack`: hold to charge, release to attack.

## Movement

- Horizontal input accelerates the player toward the configured movement speed.
- Releasing horizontal input applies friction until horizontal velocity reaches zero.
- Pressing jump while grounded applies the configured upward jump velocity.
- Gravity applies while the player is airborne.
- The player faces the most recent horizontal movement direction, except while facing is locked.
- Facing is locked during `CHARGE` and `ATTACK`.
- During `ATTACK`, friction slows horizontal velocity to zero, on the ground and in the air.

## States

- `IDLE`: selected while there is no horizontal input.
- `WALK`: selected while left or right input is held.
- `JUMP`: selected while airborne.
- `CHARGE`: selected while `melee_attack` is held; movement continues, facing is locked, and sword charge pose is shown. Charging works on the ground and in the air, and jumping while charging keeps the charge.
- `ATTACK`: selected when `melee_attack` is released after charging, on the ground or in the air, and held until the animation finishes. Jumping is not possible during `ATTACK`.
- When `ATTACK` finishes, the player returns to `IDLE` on the floor or `JUMP` in the air.
- State changes are decided once per physics frame, before the body moves, so a landing or ledge walk-off shows on the following frame.

## Damage

- The Player has 50 Health, counted in tens. A hit from an enemy hitbox costs its damage: 10 for a Scavenger's spear or a Storm Wisp's arc, so five hits defeat it.
- A hit that lands knocks the Player up and away from the hitbox (90 sideways, 120 up) and takes control away for 0.3 seconds: walk, jump and melee input are ignored, a charge or attack is lost, and the Player shows `JUMP` while tumbling.
- After a hit the Player is invulnerable for 1 second and blinks; hits during that time cost nothing.
- The Player's Health carries from Room to Room; only a defeat or a new Run refills it.
- At 0 Health the Player is defeated. It stops answering the controls, falls where it lands and flickers. Then it wakes at the first Room's `start` Entry with full Health, and the Run, its visited Rooms and its Map carry on.
- The sword's hitbox is live only during `ATTACK`, 12 pixels in front of the Player by facing; each hit costs an enemy 10 Health.

## Sound

- Sounds play on the `SFX` audio bus (`default_bus_layout.tres`), from `AudioStreamPlayer`s under the Player's `Sounds` node.
- `jump` plays when the jump impulse is applied, not when the Player walks off a ledge or is knocked into the air.
- `land` plays on returning to `IDLE` or `WALK` from `JUMP` after at least 0.08 seconds in the air, so appearing at an Entry lands quietly.
- `swing` plays when `ATTACK` begins, and `hit` when the sword strikes a Hurtbox.
- `hurt` plays when a hit lands, or `defeat` instead when it takes the last Health; the Room waits 1.2 seconds, to see the Player fall and hear the sound, before it moves the Player back to the start.
- The sounds are chiptune effects made by `scripts/tools/make_sfx.py` into `assets/audio/sfx/`; change them there and rerun it.

## Animation

- The Player rig's table in `scripts/player/player_rig.gd` declares the sheets (`player_1.png` and `weapons/sword_1.png`, 16x16 cells in one row), each animation's frames, speed and looping, the per-frame sword offsets, and what each state shows.
- Idle, Walk, Jump and Attack each show their own body animation.
- Jump plays once and holds its final frame while airborne; Attack plays once, and its end finishes the `ATTACK` state.
- While charging, the body shows `walk` when horizontal input is held and `idle` otherwise.
- The sword shows only during `CHARGE` and `ATTACK`, with its own `charge` and `attack` animations.
- Each sword frame sits at its declared offset from the body, and the body and sword mirror with facing.
- A shown animation keeps playing, even across a state change that still shows it (Walk into a moving Charge); a newly shown animation starts from its first frame.

## Ownership

- `scripts/player/player_controller.gd` (the Player controller) owns the Movement and States rules: state transitions, facing, horizontal velocity and the jump impulse.
- `scripts/player/player_rig.gd` (the Player rig) owns the Animation rules and their table.
- `scripts/player/player.gd` (the Player body) owns gravity, `move_and_slide` and reading `Input`, and hands each step's state, facing and movement to the rig. It owns the Player's Health, turns a hurtbox hit into the controller's knockback, keeps the sword hitbox live during `ATTACK`, and reports defeat.
- `scripts/player/player_controller.gd` also owns knockback and the stun that follows a hit.
- `scripts/core/main.gd` (the Room) adds the Health bar under its Pause menu, and returns the Player to the start when it is defeated. `scripts/core/run_state.gd` carries the Player's Health between Rooms and recovers the Run from a defeat.
- `scripts/ui/health_bar.gd` (the Health bar) fills to the share of the Player's Health left, in the top-left corner. A hit drops the fill at once, and a trail of the lost Health holds for 0.15 seconds, then drains over 0.5. `scripts/ui/stats_view.gd` shows `Health current / maximum` on the Stats Panel.
- `scripts/player/player_sounds.gd` (the Player sounds) owns which state changes make a sound and plays sounds by name; the Player body hands it the controller's state changes and jumps, the sword's strikes and its own hits.

## Out Of Scope

All other player behavior, including running, guarding and projectiles, will be added separately.
