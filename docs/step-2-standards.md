# Step 2 Standards

This document locks in input, collision, and naming conventions before expanding gameplay systems.

## Input Action Map

Use these action names consistently in scripts and scenes:

- `move_left`
- `move_right`
- `move_up`
- `move_down`
- `jump`
- `melee_attack`
- `ranged_attack`
- `interact`
- `pause`
- `map`

Default bindings are initialized by `scripts/core/input_setup.gd` for keyboard and gamepad.

## Collision Layer Matrix

Layer names are defined in `project.godot`.

- `world`: static level geometry
- `player`: player body
- `player_hitbox`: player melee/hurt hit regions
- `enemy`: enemy body
- `enemy_hitbox`: enemy melee/hurt hit regions
- `projectile_player`: player-fired projectiles
- `projectile_enemy`: enemy-fired projectiles
- `trigger`: room transitions, checkpoints, scripted triggers
- `pickup`: collectables and ability unlock items

### Current Baseline

- Player body uses layer `player` and collides with `world`.
- World geometry uses layer `world`.

### Expansion Rules

- Damage interactions should happen through hitbox/projectile layers, not body-body overlap.
- Keep traversal triggers on `trigger` so they can be toggled or filtered without touching combat layers.

## Naming Standards

Use snake_case for files, scripts, actions, and node names intended for code access.

Examples:

- Scenes: `world_room_01.tscn`, `player.tscn`
- Scripts: `player.gd`, `input_setup.gd`
- Actions: `ranged_attack`, `move_left`
- Autoload singleton names: PascalCase (for example `InputSetup`)
