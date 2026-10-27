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

- `res://assets/sprites/player_1.png` is the player sprite sheet.
- Frames use a 16x16 grid.
- Idle uses frame 0.
- Walk loops through frames 0 and 1.
- Jump plays frames 2, 3, and 4 once and holds its final frame while airborne.
- Attack uses player frames 5 and 6.
- Charge shows sword frame 1 from `sword_1.png` at `sword_charge_offset`, mirrored by facing.
- The attack displays sword frames 0 and 1 from `sword_1.png` at the same time.
- Each sword frame uses its matching entry in `sword_attack_frame_offsets` and mirrors with facing.
- Sprite frames are constructed programmatically in `scripts/player/player.gd`.
- While charging, the body shows `walk` when horizontal input is held and `idle` otherwise.

## Ownership

- `scripts/player/player_controller.gd` (the Player controller) owns the Movement and States rules: state transitions, facing, horizontal velocity and the jump impulse.
- `scripts/player/player.gd` (the Player body) owns gravity, `move_and_slide`, reading `Input`, and the Animation rules until they move to a dedicated rig.

## Out Of Scope

All other player behavior, including running, damage, and projectiles, will be added separately.
