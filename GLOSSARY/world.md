# World

**World**:
Every Region and every Room, with where each Room sits and how many screens it spans. The Map draws it.
_Avoid_: World map, level list, Map (for what the Map draws)

**Run**:
One playthrough from a new game. It remembers where the Player is in the world and what they have done. Only START begins a new one; a defeat keeps it.
_Avoid_: Session, save, runtime state

**Room**:
One area of the world, loaded as a single scene.
_Avoid_: Level, map, screen

**Planned Room**:
A Room laid out in the World, with its place, size, Region and Exits, before it is built. Only the Map drawn from the Plan shows it; the game leaves it out until it has a scene.
_Avoid_: Placeholder room, stub, draft room

**Plan**:
The layout agreed for the World ahead of building it: where each Planned Room goes, and where built Rooms are to move. The game plays the World as it is; the Map can draw it as planned. Each Room's plan folds into it as the Room is built or moved.
_Avoid_: Blueprint, draft, roadmap

**World editor**:
The local web app for laying out the World, Region by Region and Room by Room, and for painting each Room's tiles from its Region's sheets. It draws the World as the Map does and leaves the rest of a Room to Godot.
_Avoid_: Map editor, level editor

**Entry**:
A named place in a Room where the Player appears on entering it. A new Run begins at the first Room's `start` Entry.
_Avoid_: Spawn point, start position, door

**Exit**:
An edge of a Room that leads to an Entry in another Room. Crossing it enters that Room in the Run and loads its scene.
_Avoid_: Door, portal, transition, warp

**Region**:
A stretch of the world with its own theme, Map name and colour, such as the Waking Coast. A Region has a Safe spoke or leans on a neighbouring one, as the Waking Coast and the Undertow beneath its cliffs both lean on Tidefen Village.
_Avoid_: Biome, zone, area, level

**Safe spoke**:
A small place with no enemies, where people, a Rest point and shops are. It may be a small Region of its own, such as Tidefen Village past the Waking Coast, with its own theme, Map name and colour.
_Avoid_: Hub, village, town (as a kind of place)

**Villager**:
Someone who lives in a Safe spoke and talks when the Player uses them with Interact, named in the Dialogue box by the trade they keep, such as Tidefen's netter, knot-weaver, bell-keeper and fisher, and its TRADER, who keeps the Supply Shop. They stand by their part of the village, idling, turn to face the Player, and say the same few lines each time.
_Avoid_: NPC, townsperson, extra

**Rest point**:
A place in a Safe spoke where the Player recovers, and which a defeat returns them to without ending the Run. Tidefen's is its bell: rung with Interact, it tolls, refills Health and every Sub Weapon owned, shows RESTED, and from then on a defeat wakes the Player at its foot. It can be rung again at any time.
_Avoid_: Checkpoint, save point, bonfire

**Supply Shop**:
Where the Player buys Supplies with Gold. Tidefen's is kept by the TRADER at the market stall, a Villager whom talking to opens it, with play paused: Meat Pies for 15 Gold and Brinecaps for 8. A Supply the Player lacks the Gold or the room for is greyed.
_Avoid_: Store, vendor, merchant (as the place)

**Background**:
The distant layers of a Region drawn behind its Rooms, each scrolling slower the farther back it is: for the Waking Coast, a sky with the sun and its beams fixed in it, clouds far and near, ships sailing on the horizon, and the sea. Every Room in the Region shows the same Background, set by where the Room sits in the world, so it carries on across Exits; the caves show a dark rock wall instead.
_Avoid_: Backdrop, skybox, parallax (as a thing)

**Region theme**:
The music of a Region, such as the Waking Coast's. It plays in each of the Region's Rooms outside its Safe spoke, which has a theme of its own, and carries on unbroken through Exits between them.
_Avoid_: Level music, BGM, soundtrack

**Intro**:
Chapter 1's opening on a new game from the start screen: Vael wakes in the surf in the middle of the beach, and Mara comes in from the wreck, pulls his sword out of the sand and hands it to him as they talk. A restarted Run skips it.
_Avoid_: Cutscene, prologue, tutorial
