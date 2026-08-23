# Setting

## Region-by-Region Progression (Metroidvania Flow)

1. Waking Coast: Waking Coast (start) -> Tidefen Village safe spoke.
2. Low Canopy Jungle: Low Canopy Jungle -> Shrinekeeper Camp safe spoke -> Smuggler Inlet and Pirate Fort.
3. Underroot: Emberroot Village safe spoke -> Underroot Cave System -> Relic Chamber (unlock: double jump).
4. High Canopy: backtrack to Jungle shrine locks -> High Canopy Jungle -> Canopy Refuge safe spoke -> Canopy Shaft -> Observatory Ridge.
5. Northern Reaches: North Shoals -> Floating Causeway -> Glassmire Village safe spoke.
6. Stormwatch Tower: Stormglass Refuge safe spoke -> Stormwatch Tower (unlock: arcane seal key).
7. Blackreef Approach: Ironwake Village safe spoke -> Castle Approach.
8. Blackreef Castle: Blackreef Castle -> Warden's Rest safe spoke -> Book Vault.

## Metroidvania Layout Rules

- Each major region has one smaller safe spoke with no enemy encounters.
- Safe spokes may contain NPCs, rest points, vendors, or story interactions.
- Every major branch must loop back to at least one earlier hub.
- Ability unlocks open at least two old gates, not just one new path.
- Vertical lanes (caves/canopy/tower) should reconnect to horizontal lanes (villages/coast/fort).
- Endgame areas should be reachable from multiple late-game hubs.

## Spoke Areas

- **Tidefen Village**: Weathered stilt houses, shell-strung walkways, and blue lanterns cluster above calm tidal pools.
- **Shrinekeeper Camp**: Mossy canvas shelters and herb racks circle a restored stone shrine beneath the Low Canopy.
- **Emberroot Village**: Basalt homes and open forges glow red around mineral vents rising from the dark earth.
- **Canopy Refuge**: Small wooden platforms and leaf-roofed huts hang quietly among immense roots above the jungle floor.
- **Glassmire Village**: Narrow homes with mirrored shutters stand on pale boardwalks crossing still, reflective wetlands.
- **Stormglass Refuge**: A sheltered observatory annex of dark glass and copper overlooks rain suspended around Stormwatch Tower.
- **Ironwake Village**: Reinforced stone barracks, supply yards, and iron gates form a compact settlement beneath the castle road.
- **Warden's Rest**: A sealed cloister of white stone, cold gold lamps, and intact oath banners lies hidden within Blackreef.

## Metroidvania Cartography-Style ASCII Map

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

- [DJ-1/2/3]: double jump gate tiers
- [AK]: arcane key gate from Stormwatch Tower
- LIFT: one-way shortcut loop that reconnects a dungeon branch to a hub

## Enemy Catalog

Regional enemies and bosses are listed in the [enemy catalog](../enemies/README.md).

## Region Descriptions

### Waking Coast

Once the ceremonial landing site for wardens sworn to protect forbidden knowledge, the Waking Coast is where all oaths began. During the Memory Tempests, the tide carried shattered oath-stones back to shore, and each storm stripped names from their carvings. The fisher-families of nearby Tidefen abandoned deep water after seeing lights beneath the waves and became practical salvagers and mapmakers, preserving identity through memory-knot rituals and strict bell curfews. Vael's survival of the black surf marks him as oathbound blood, while Ilyr's scouts buying old charts makes his arrival seem like either fate or a dangerous omen.

### Low Canopy Jungle

The Low Canopy was once a medicine garden maintained by shrine keepers, but roots swallowed its terraces after the wardens fell and alchemical runoff transformed its wildlife into territorial packs. Beneath the vines, broken reliefs show the Book of All being carried inland under guard. The jungle descends to Smuggler Inlet, a former warden supply harbor where contraband moves during thunder squalls when memory echoes are weakest, and to a naval watchtower claimed by corsairs and remade as the Pirate Fort. Its crews sell relics, prisoners, and false maps while guarding rumors of a service tunnel to Blackreef, and Ilyr secured their aid by trading arcane protection for access to those deep vault routes.

### Underroot

Underroot begins at Emberroot, a settlement built on mineral-hot ground around forges that once produced ceremonial warden tools. Its proud smith clans disagree over whether the island should be resealed or conquered, but their respect for proven strength gives Vael a path into the caves below. Underground rivers carved these oldest foundations before wardens covered them in script, turning their deepest chambers into resonators that replay the memories of anyone passing through. At their heart, a Relic Chamber once trained initiates to move through low-gravity currents; sealed after a failed levitation rite collapsed a hall, it now grants its double-jump sigil only to someone seeking power for a purpose beyond possession.

### High Canopy

The High Canopy formed above collapsed ruins as a suspended world of roots, stone bridges, blind predators, and old warden zipline anchors. Scout clans once used it as a silent courier highway between villages, reached through Canopy Shaft, a ruined watch elevator and relic checkpoint whose walls record those who failed its climb. The route ends at Observatory Ridge, where astronomer-priests tracked celestial tides that influence memory erosion and predicted the island's catastrophe before leaders seeking the Book ignored them. Its surviving instruments can still align hidden paths across the island, but every activation broadcasts a signal that draws hostile arcane entities.

### Northern Reaches

The Northern Reaches begin at the windswept cliffs and tidal shelves of North Shoals, where one ancient beacon still flashes on storm nights without a known operator. Beyond it, a Floating Causeway built with anti-gravity anchors once carried relics above hostile ground, but the island's fracture left its drifting spans open only in brief traversal windows; restoring it is both a breakthrough and a declaration visible to every faction. The route reaches Glassmire, a scholar refuge built around mirrored wetlands whose people preserve history in layered chants that resist written corruption and memory loss. Its elders hold the strongest surviving account of Vael's oathbound past and reveal it only after his actions prove that the timing and their trust are aligned.

### Stormwatch Tower

Originally a weather and ward control spire, the tower became an arcane laboratory after traditional wardens died out. Ilyr chose it as his operational base because it amplifies ritual precision and can project lock-breaking frequencies across the island. The arcane key obtained here is less a key than a tuning pattern that destabilizes old seal geometry.

### Blackreef Approach

The Blackreef Approach begins at Ironwake, a military logistics camp hardened into a disciplined frontier stronghold whose people value duty over myth. Standing closest to the castle threat, they are prepared to burn their own district rather than let dark arcane forces spill west. Beyond the village, old battlements and processional roads once welcomed sworn guardians into the final sanctum; now traps, failed constructs, and rival strike teams contest a route deliberately designed to exhaust intruders before they reach the inner gates.

### Blackreef Castle

Blackreef Castle was never a royal home; it is a prison-temple built to contain knowledge judged too dangerous for any age. Its outer halls preserve sanctioned doctrine while its inner circles hide forbidden praxis and weaponized memory rites, testing the motives of anyone seeking the Book rather than strength alone. Beneath them lies the Book Vault, the final lock in the island's seal network, where layered oaths demand both bloodline resonance and cognitive endurance. The vault does not merely reveal knowledge: it reflects each seeker's deepest justification and magnifies it.
