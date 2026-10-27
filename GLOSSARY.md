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
The Player's physical presence in the world: collision, gravity, sliding along surfaces, and what is drawn on screen.
_Avoid_: Player node, player scene

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
