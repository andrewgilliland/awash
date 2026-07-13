# Testing

Awash includes a lightweight built-in headless test runner for smoke checks.

## Run

```bash
./scripts/quality/test.sh
```

## What It Covers Now

- Player scene loads correctly.
- Player defaults are sane for initial movement tuning.

## Expand Later

- Add physics behavior tests for jump buffering and coyote timing.
- Add tests for combat action setup and progression flags.

## Player Spec Coverage

The player behavior spec in [docs/specs/player-spec.md](docs/specs/player-spec.md) is the source of truth for the current vertical slice.

### Current Coverage

- [awash/tests/test_runner.gd](awash/tests/test_runner.gd) already protects the current smoke surface:
  - Player scene loads correctly.
  - Player defaults stay sane.
  - Movement tuning stays within expected bounds.
  - Run double-tap input activates run.
  - Crouch and guard cancel run input.
  - Jump buffer and coyote timing stay wired.
  - Coyote time allows jump.
  - Jump buffer fires on landing.
  - Crouch blocks run and guard blocks crouch.
  - Melee attack windows advance correctly.
  - Player state machine relay stays wired.
  - Crouch sprite animates.
  - Walk animation uses walk fps.
  - Sprite visual is scaled down.
  - Attack animation uses larger frame size.
  - Guard and charge sprites differ.
  - Guard and charge animation mapping is correct.
  - Charge release starts the attack.
  - Blocked states prevent ranged fire.
  - Ranged defaults stay sane.
  - Camera defaults stay sane.

### Next Tests To Add

- Movement
- Combat
  - [ ] `_test_player_melee_hits_each_target_once`
  - [ ] `_test_player_guard_reduces_damage_and_knockback`
  - [ ] `_test_player_ranged_cooldown_and_resource`
- State
  - [ ] `_test_player_hurt_locks_state_changes`
  - [ ] `_test_player_death_cancels_attack_and_locks_state`
- Visual
  - [ ] `_test_player_runtime_sprite_sheet_keys_background`
  - [ ] `_test_player_state_to_animation_mapping_covers_jump_fall_hurt_death`

### File Ownership

- [awash/scripts/core/input_setup.gd](awash/scripts/core/input_setup.gd) owns the control contract and default bindings.
- [awash/scripts/player/player.gd](awash/scripts/player/player.gd) owns orchestration, state updates, and scene-facing behavior.
- [awash/scripts/player/player_combat.gd](awash/scripts/player/player_combat.gd) owns attack windows, projectile firing, and combat hit rules.
- [awash/scripts/player/player_sprite_factory.gd](awash/scripts/player/player_sprite_factory.gd) owns runtime sprite construction and animation frame setup.
- [awash/scripts/player/player_state_machine.gd](awash/scripts/player/player_state_machine.gd) owns state storage and change notifications.
