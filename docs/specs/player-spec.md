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
- `scripts/player/player.gd` (the Player body) owns gravity, `move_and_slide` and reading `Input`, and hands each step's state, facing and movement to the rig.

## Out Of Scope

All other player behavior, including running, damage, and projectiles, will be added separately.
