# Setting

## Region Progression

1. [Waking Coast](regions/waking-coast.md): Waking Coast (start) -> [Tidefen Village](regions/tidefen-village.md).
2. [Low Canopy Jungle](regions/low-canopy-jungle.md): Low Canopy Jungle -> [Shrinekeeper Camp](regions/shrinekeeper-camp.md) -> Smuggler Inlet and Pirate Fort.
3. [Underroot](regions/underroot.md): [Emberroot Village](regions/emberroot-village.md) -> Underroot Cave System -> Relic Chamber (unlock: double jump).
4. [High Canopy](regions/high-canopy.md): Jungle shrine locks -> High Canopy Jungle -> [Canopy Refuge](regions/canopy-refuge.md) -> Canopy Shaft -> Observatory Ridge.
5. [Northern Reaches](regions/northern-reaches.md): North Shoals -> Floating Causeway -> [Glassmire Village](regions/glassmire-village.md).
6. [Stormwatch Tower](regions/stormwatch-tower.md): [Stormglass Refuge](regions/stormglass-refuge.md) -> Stormwatch Tower (unlock: arcane seal key).
7. [Blackreef Approach](regions/blackreef-approach.md): [Ironwake Village](regions/ironwake-village.md) -> Castle Approach.
8. [Blackreef Castle](regions/blackreef-castle.md): Blackreef Castle -> [Warden's Rest](regions/wardens-rest.md) -> Book Vault.

## Layout Rules

- Each major region has one smaller safe spoke with no enemy encounters.
- Safe spokes may contain NPCs, rest points, vendors, or story interactions.
- Every major branch must loop back to at least one earlier hub.
- Ability unlocks open at least two old gates, not just one new path.
- Vertical lanes reconnect to horizontal lanes where possible.
- Endgame areas are reachable from multiple late-game hubs.

## Region File Schema

- Major-region frontmatter stores `name`, `type`, `chapter`, `safe_spoke`, `key_areas`, progression gates or unlocks, and `enemy_roster`.
- Safe-spoke frontmatter stores `name`, `type`, `parent_region`, `enemies`, `npcs`, `shop`, and `visual`.

## Region Index

| Major Region                                        | Safe Spoke                                        |
| --------------------------------------------------- | ------------------------------------------------- |
| [Waking Coast](regions/waking-coast.md)             | [Tidefen Village](regions/tidefen-village.md)     |
| [Low Canopy Jungle](regions/low-canopy-jungle.md)   | [Shrinekeeper Camp](regions/shrinekeeper-camp.md) |
| [Underroot](regions/underroot.md)                   | [Emberroot Village](regions/emberroot-village.md) |
| [High Canopy](regions/high-canopy.md)               | [Canopy Refuge](regions/canopy-refuge.md)         |
| [Northern Reaches](regions/northern-reaches.md)     | [Glassmire Village](regions/glassmire-village.md) |
| [Stormwatch Tower](regions/stormwatch-tower.md)     | [Stormglass Refuge](regions/stormglass-refuge.md) |
| [Blackreef Approach](regions/blackreef-approach.md) | [Ironwake Village](regions/ironwake-village.md)   |
| [Blackreef Castle](regions/blackreef-castle.md)     | [Warden's Rest](regions/wardens-rest.md)          |

## Shop Types

- **Supply Shop**: Sells healing items, ammunition, antidotes, and other basic consumables.
- **Smith**: Sells and upgrades weapons, armor, and combat equipment.
- **Mystic**: Sells relics, arcane consumables, and memory-related services.

## World Map

```text
  WEST EDGE                                                           EAST EDGE

  [NORTH SHOALS]--------------------------[FLOATING CAUSEWAY]-------------------+
        |                                         |                             |
  [OBSERVATORY RIDGE]====[HIGH CANOPY JUNGLE]====[CANOPY REFUGE]====[GLASSMIRE VILLAGE V3]
        |                    ||     [DJ-2]                                  |
        |                    ||                          [STORMGLASS REFUGE]==[STORMWATCH TOWER]-+-[AK]
        |                    ||                                           |      |
  [CANOPY SHAFT]==============+====================[CASTLE APPROACH]=======+      |
        |                                                ||                       |
        |                                                ||                 [BLACKREEF]
  [LOW CANOPY JUNGLE]====[SHRINEKEEPER CAMP]====[SMUGGLER INLET/PIRATE FORT]====++====[IRONWAKE V4]
        ||                         ||          (LIFT)                             |
        ||                         ||                                        [WARDEN'S REST]
        ||                         ||                                             |
        ||                         ||                                        [BOOK VAULT]
  [TIDEFEN V1]======================++=============================================+
        |
  [WAKING COAST]
        |
  [EMBERROOT V2]====================[UNDERROOT CAVES]====[RELIC CHAMBER]
                                    ||                    |
                                    ||                    +--- UNLOCK: DOUBLE JUMP
                                    ||
                                    +===== BACKTRACK GATES OPEN =====>
                                         [LOW JUNGLE DJ-1]
                                         [HIGH CANOPY DJ-2]
                                         [CASTLE SHAFT DJ-3]
```

## Gate Legend

- `[DJ-1/2/3]`: Double-jump gate tiers.
- `[AK]`: Arcane-key gate from Stormwatch Tower.
- `LIFT`: One-way shortcut loop that reconnects a dungeon branch to a hub.

## Related Documents

- [Enemy catalog](../enemies/README.md)
- [Story outline](../story/story.md)
