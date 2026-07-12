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

## Day-by-Day Plan
1. Day 1: Project bootstrap, display/stretch setup, folder taxonomy.
2. Day 2: Input map (keyboard and gamepad), collision matrix, naming standards.
3. Day 3: Locomotion and jump feel tuning (coyote and buffer), baseline animation linking.
4. Day 4: State graph plus hurt/death foundations.
5. Day 5: Melee attack windows and hit feedback events.
6. Day 6: Ranged projectile system and cooldown/resource rules.
7. Day 7: Camera dead zone, look-ahead, room clamps, and polish pass.
8. Day 8: 3-5 room biome blockout with layered TileMaps.
9. Day 9: Room transitions with persistent runtime state.
10. Day 10: Double-jump unlock event and gated-route revalidation.
11. Day 11: Enemy archetype and encounter balancing.
12. Day 12: Checkpoint/respawn, unlock persistence, and minimal HUD.
13. Day 13: Audio bus and VFX/UI feedback polish.
14. Day 14: QA pass, controller parity, desktop export smoke test, and backlog for the next milestone.

## Verification Gate
1. Keyboard and controller parity passes.
2. Progression gate blocks before unlock and opens after unlock.
3. Melee and ranged are both viable in encounter.
4. Save/restart preserves ability unlock and checkpoint flow.
5. Desktop export launches and plays without critical regressions.

## Scope Boundaries
- In scope: one biome slice, one enemy archetype, one ability gate.
- Out of scope: full world map system, quest/dialogue stack, large enemy roster.
