# Awash

A side-scrolling metroidvania/action RPG. This glossary covers the language of the Player and how they act in the world.

## Player

**Player**:
The character the person playing controls.
_Avoid_: Hero, character (when the Player specifically is meant)

**Player controller**:
The rules that decide the Player's state, facing and movement from one frame of input and world facts.
_Avoid_: Player brain, player motor, state machine

**Player body**:
The Player's physical presence in the world: collision, gravity and sliding along surfaces. It hands what to draw to the Player rig.
_Avoid_: Player node, player scene

**Player rig**:
What is drawn for the Player in each Player state and Facing: the body and the sword.
_Avoid_: Animator, sprite controller

**Player state**:
Exactly one of Idle, Walk, Jump, Charge or Attack at any moment.
_Avoid_: Mode, action

**Facing**:
The horizontal direction the Player looks and strikes toward; left or right, never neutral.
_Avoid_: Direction, orientation

**Interact**:
The button for using whatever the Player stands by: E, or Y / Triangle on a gamepad. It uses the nearest Interactable in reach, and does nothing while the Player is held still.
_Avoid_: Action button, use, talk

**Use**:
The button that spends the ready Supply, chosen in the Equipment Panel, without pausing play.
_Avoid_: Item button, quick-use, consume

**Interactable**:
Anything Interact can use, such as Mara. It reports being used and shows a bobbing arrow above itself while the Player is in reach; what using it does is up to its owner.
_Avoid_: Usable, trigger, hotspot

**Charge**:
The Player state while melee is held: the sword is raised, movement continues, and facing is locked.
_Avoid_: Wind-up, hold

**Attack**:
The Player state from melee release until the swing finishes: facing is locked, jumping is not possible, and horizontal movement bleeds to a stop.
_Avoid_: Swing, strike (as state names)

## World

**Run**:
One playthrough from a new game. It remembers where the Player is in the world and what they have done. Only START begins a new one; a defeat keeps it.
_Avoid_: Session, save, runtime state

**Room**:
One area of the world, loaded as a single scene.
_Avoid_: Level, map, screen

**Entry**:
A named place in a Room where the Player appears on entering it. A new Run begins at the first Room's `start` Entry.
_Avoid_: Spawn point, start position, door

**Exit**:
An edge of a Room that leads to an Entry in another Room. Crossing it enters that Room in the Run and loads its scene.
_Avoid_: Door, portal, transition, warp

**Region**:
A stretch of the world with its own theme and Map name, such as the Waking Coast. Each has one Safe spoke.
_Avoid_: Biome, zone, area, level

**Safe spoke**:
The one small place in a Region with no enemies, where its people, Rest point and shops are, such as Tidefen Village. It belongs to its Region but goes by its own name.
_Avoid_: Hub, village, town (as a kind of place)

**Rest point**:
A place in a Safe spoke where the Player recovers, and which a defeat returns them to without ending the Run.
_Avoid_: Checkpoint, save point, bonfire

**Region theme**:
The music of a Region, such as the Waking Coast's. It plays in each of the Region's Rooms outside its Safe spoke, which has a theme of its own, and carries on unbroken through Exits between them.
_Avoid_: Level music, BGM, soundtrack

**Intro**:
Chapter 1's opening on a new game from the start screen: Vael wakes in the surf in the middle of the beach, and Mara comes in from the wreck, pulls his sword out of the sand and hands it to him as they talk. A restarted Run skips it.
_Avoid_: Cutscene, prologue, tutorial

## Layout

**Main path**:
The Rooms a Run must pass through, in order, from a Region's start to its end.
_Avoid_: Critical path, main route, golden path

**Branch**:
An optional route off the Main path that rejoins it, such as the sea cave.
_Avoid_: Side path, detour, secret area

**Shortcut**:
A one-way route that returns the Player quickly to an earlier point on the Main path, such as Tidefen's well through the undertow. It stays shut from its far end until first used from its near end.
_Avoid_: Branch (for a one-way return), warp

**Drop**:
An Exit the Player falls through into a Room below, with no way back up. A sinkhole or a well is just what a Drop looks like.
_Avoid_: Pit, sinkhole, chute, hole (as the general term)

**Gate**:
A place on a route that stays shut until an ability unlock or a defeated boss opens it, such as the ledge above the salt cliffs that double jump will reach.
_Avoid_: Lock, barrier, door

**Cache**:
A hidden spot in a Room holding Supplies, opened with Interact, that stays empty once taken for the Run.
_Avoid_: Crate, chest, stash, pickup

**Supply**:
A consumable used in exploration or combat, such as a Restorative, bought at a Supply Shop or found in a Cache.
_Avoid_: Item, consumable, loot (as the general term)

**Tide Draught**:
The first Restorative: a Supply that restores 2 Health.
_Avoid_: Potion, health potion

**Salvage**:
What the Player gathers from the wreck-strewn world and spends at shops. Defeated enemies drop it, Caches can hold it, and a defeat does not take it away.
_Avoid_: Gold, coins, money, currency

**Memory Relic**:
A rune that restores a flash of Vael's past when found, such as the one waiting in the rune alcove above the salt cliffs.
_Avoid_: Memory shard, flashback item

## Combat

**Health**:
How many more hits something can take, in whole points. Reaching 0 is defeat.
_Avoid_: HP, hit points, life

**Hitbox**:
The part of an attack that strikes, such as the Player's sword or a Scavenger's spear. It only strikes while live.
_Avoid_: Damage box, attack area

**Hurtbox**:
The part of a body that can be struck by a Hitbox.
_Avoid_: Hitbox (for the struck side), body

**Knockback**:
The throw a landed hit gives the struck body, away from the Hitbox.
_Avoid_: Recoil, push

**Scavenger**:
The Waking Coast's fish-man enemy: it patrols a tidal pool and lunges with a hooked spear after a wind-up.
_Avoid_: Sahagin, fish-man (as a name)

## Menus

**Dialogue box**:
Shows a conversation one line at a time, typed out, with the speaker's name; a press finishes a line or moves to the next. The Player is held still while it is open.
_Avoid_: Text box, speech bubble, message window

**Start screen**:
Where the game opens: the AWASH logo over the coast, its looping theme, and a PRESS START prompt that opens START and QUIT. START begins a new Run.
_Avoid_: Title screen, main menu, splash

**Pause menu**:
Pauses play and offers Resume, Quit and its Panels.
_Avoid_: Options menu, start menu

**Panel**:
One page of the Pause menu, opened from its menu button and closed with Back. Home is the Panel shown when no other is open.
_Avoid_: Tab, screen, page

**Map**:
The Panel that draws each visited Room as a block, sized in screens, with the name of the Region or Safe spoke the Player is in and a dot where the Player stands. Unvisited Rooms stay hidden.
_Avoid_: Minimap, world map, atlas
