# Awash Daily Plan

## Goal

Build a side-scrolling Godot 4.4 metroidvania/action RPG vertical slice with melee and ranged combat, a double-jump progression gate, and early gamepad support.

## Milestone Outcome

Player can start a new game, clear a small biome, unlock double-jump, and backtrack through a previously gated route in under 10 minutes.

## Implementation Checkpoint (2026-07-11)

- Initial awash project scaffold created.
- Runnable graybox foundation scene added.
- Runtime keyboard and gamepad input bootstrap added.
- Starter player controller added with coyote time and jump buffering.
- Optional double-jump toggle added in player script.
- Player spritesheet integration added with runtime background cleanup and animation playback wiring.

## Steps

1. Project bootstrap, display/stretch setup, folder taxonomy.
   1. Add typechecking gate and run it before moving into Day 2 feature work.
   2. Add linting and formatting gate and run it before moving into Day 2 feature work.
   3. Add test gate and run it before moving into Day 2 feature work.
   4. Configure VS Code Godot tooling (extensions and workspace settings).
2. Input map (keyboard and gamepad), collision matrix, naming standards.
3. Locomotion and jump feel tuning (coyote and buffer), baseline animation linking.
   1. Tune ground acceleration, air acceleration, and friction for tighter left-right control.
   2. Tune jump arc values, including jump velocity, fall cap, and jump-release gravity.
   3. Clean up animation-state transitions for idle, run, jump, fall, and attack overlap.
   4. Recheck sprite footing and visual offset while moving, jumping, and landing.
   5. Add or expand movement-focused tests to protect feel-critical controller behavior.
4. State graph plus hurt/death foundations.
5. Melee attack windows and hit feedback events.
6. Ranged projectile system and cooldown/resource rules.
7. Camera dead zone, look-ahead, room clamps, and polish pass.
8. 3-5 room biome blockout with layered TileMaps.
9. Room transitions with persistent runtime state.
10. Double-jump unlock event and gated-route revalidation.
11. Enemy archetype and encounter balancing.
12. Checkpoint/respawn, unlock persistence, and minimal HUD.
13. Audio bus and VFX/UI feedback polish.
14. QA pass, controller parity, desktop export smoke test, and backlog for the next milestone.

## Verification Gate

1. Keyboard and controller parity passes.
2. Progression gate blocks before unlock and opens after unlock.
3. Melee and ranged are both viable in encounter.
4. Save/restart preserves ability unlock and checkpoint flow.
5. Desktop export launches and plays without critical regressions.

## Scope Boundaries

- In scope: one biome slice, one enemy archetype, one ability gate.
- Out of scope: full world map system, quest/dialogue stack, large enemy roster.
