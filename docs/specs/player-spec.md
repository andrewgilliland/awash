# Player Behavior Spec

## Purpose

This spec defines the minimal player baseline while player behavior is rebuilt.

## Controls

- `move_left`: move horizontally to the left.
- `move_right`: move horizontally to the right.

## Movement

- Horizontal input accelerates the player toward the configured movement speed.
- Releasing horizontal input applies friction until horizontal velocity reaches zero.
- Gravity applies while the player is airborne.
- The player faces the most recent horizontal movement direction.

## States

- `IDLE`: selected while there is no horizontal input.
- `WALK`: selected while left or right input is held.
- `ATTACK`: selected when `melee_attack` is pressed and held until the animation finishes.

## Animation

- `res://assets/sprites/player_1.png` is the player sprite sheet.
- Frames use a 16x16 grid.
- Idle uses frame 0.
- Walk loops through frames 0 and 1.
- Attack uses player frames 5 and 6.
- The attack displays sword frames 0 and 1 from `sword_1.png` at the same time.
- Each sword frame uses its matching entry in `sword_attack_frame_offsets` and mirrors with facing.
- Sprite frames are constructed programmatically in `scripts/player/player.gd`.

## Out Of Scope

All other player behavior, including jumping, running, damage, and projectiles, will be added separately.
