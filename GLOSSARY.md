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
A named place in a Room where the Player appears on entering it. Each Room has a default Entry where a new Run begins.
_Avoid_: Spawn point, start position, door

## Menus

**Pause menu**:
Pauses play and offers Resume, Quit and its Panels.
_Avoid_: Options menu, start menu

**Panel**:
One page of the Pause menu, opened from its menu button and closed with Back. Home is the Panel shown when no other is open.
_Avoid_: Tab, screen, page
