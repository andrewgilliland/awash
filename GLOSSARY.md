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

**Charge**:
The Player state while melee is held: the sword is raised, movement continues, and facing is locked.
_Avoid_: Wind-up, hold

**Attack**:
The Player state from melee release until the swing finishes: facing is locked, jumping is not possible, and horizontal movement bleeds to a stop.
_Avoid_: Swing, strike (as state names)

## World

**Run**:
One playthrough from a new game. It remembers where the Player is in the world and what they have done.
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

**Region theme**:
The music of a region, such as the Waking Coast's. It plays in each of the region's Rooms and carries on unbroken through Exits between them.
_Avoid_: Level music, BGM, soundtrack

**Intro**:
Chapter 1's opening on a new game from the start screen: Vael wakes in the surf by the wreck and Mara comes over to talk. A restarted Run skips it.
_Avoid_: Cutscene, prologue, tutorial

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
The Panel that draws each visited Room as a block, sized in screens, with the current Room's region and a dot where the Player stands. Unvisited Rooms stay hidden.
_Avoid_: Minimap, world map, atlas
