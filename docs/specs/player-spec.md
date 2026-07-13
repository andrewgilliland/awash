# Player Behavior Spec

## Purpose

This spec defines the current player behavior contract for the Awash vertical slice. It covers the player-facing controls, the expected movement and combat rules, and the observable state transitions that existing tests should protect.

## Control Contract

The player must respond to these abstract actions and their current physical bindings:

- `move_left`: Left Arrow, A, left stick / left D-pad
- `move_right`: Right Arrow, D, right stick / right D-pad
- `move_up`: Up Arrow, W, up stick / up D-pad
- `move_down`: Down Arrow, S, down stick / down D-pad
- `jump`: Space, gamepad button 0
- `guard`: C, gamepad button 4
- `melee_attack`: X, gamepad button 2
- `ranged_attack`: V, gamepad button 1
- `interact`: E, gamepad button 3

The abstract actions are the behavior contract. The physical bindings are the current implementation detail that makes the contract usable immediately on keyboard and controller.

## Movement Rules

- Pressing `move_left` or `move_right` moves the player horizontally.
- Holding no horizontal input should let friction bring horizontal movement back toward zero.
- Pressing `move_left` or `move_right` twice within the configured double-tap window activates run.
- Running should stop when the player crouches or guards.
- Pressing `jump` from the ground should start a jump.
- Jump input buffered shortly before landing should still trigger a jump.
- Jump input used within coyote time after leaving the ground should still trigger a jump.
- If double jump is enabled, the player may jump again in the air up to the configured air-jump limit.
- Releasing `jump` while moving upward should shorten the jump by increasing downward gravity.
- Pressing `move_down` while grounded should enter crouch when guard is not being requested.

## Combat Rules

- Pressing and holding `melee_attack` while grounded should put the player into charge.
- Releasing `melee_attack` while charging should start the melee attack sequence.
- Melee attack should have distinct startup, active, and recovery windows.
- Melee damage should only apply during the active window.
- A target should only be hit once per melee attack sequence.
- Pressing `ranged_attack` should fire a projectile when the player is not blocked and has enough ranged resource.
- Ranged attack must be blocked while the player is dead, hurt, guarding, or charging.
- Ranged attack must respect cooldown and ranged resource cost.
- Guarding on the ground should reduce incoming damage and knockback.
- A full guard block should emit the guard-block feedback event.

## State Rules

- The player state machine should always reflect the current gameplay state.
- `IDLE`, `WALK`, `RUN`, `JUMP`, `FALL`, `ATTACK`, `CROUCH`, `GUARD`, `CHARGE`, `HURT`, and `DEAD` are the supported player states.
- Hurt should lock state changes until its timer expires.
- Death should cancel attack flow and transition to dead state.
- If scene reload on death is enabled, the current scene should reload after the death timer expires.

## Visual Rules

- The runtime sprite sheet should be built from the source player sprite sheet with the keyed background made transparent.
- The current state should select the expected animation: idle, walk, run, jump up, jump down, attack, crouch, guard, charge, hurt, or death.
- The camera should apply the configured room clamp and look-ahead behavior.

## Verification

Existing headless tests and any new focused tests should prove the following:

- Movement defaults are sane.
- Guard and charge sprites differ.
- Guard and charge animation mapping is correct.
- Charge release starts the attack.
- Blocked states prevent ranged fire.
- Player scene loads and player defaults remain stable.

Targeted follow-up tests should be added for:

- Run activation from double-tap timing.
- Coyote time and jump buffering.
- Guard damage and knockback reduction.
- Melee single-hit-per-target behavior.
- State-machine signal relay on state changes.

## Out of Scope

- Progression gates beyond the current player ability set.
- Enemy roster expansion.
- Save system persistence beyond the current runtime state behavior.
- Map, quest, and dialogue systems.