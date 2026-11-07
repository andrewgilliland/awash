# Player

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

**Interactable**:
Anything Interact can use, such as Mara. It reports being used and shows a bobbing arrow above itself while the Player is in reach; what using it does is up to its owner.
_Avoid_: Usable, trigger, hotspot

**Sign**:
Something in a Room the Player looks at with Interact, such as the lake's sealed temple door, which shows a few lines in the Dialogue box in its speaker's name, "???" for Vael's own thoughts.
_Avoid_: Notice, inspectable, examine point

**Charge**:
The Player state melee goes on into when it is still held as the slash it pressed finishes: the sword is held out ready, movement continues, and facing is locked. Let go before it is full and it just ends, with no second swing.
_Avoid_: Wind-up, hold

**Attack**:
The Player state from a melee press, or from letting go of a full Charge, until the swing finishes: facing is locked, jumping is not possible, and horizontal movement bleeds to a stop. A press slashes at once.
_Avoid_: Swing, strike (as state names)

**Charged Attack**:
An Attack let go after a full Charge, half a second of holding melee from the press. The sword blinks once the Charge is full, and it swings lit; the swing itself strikes nothing, and the Sword Beam it looses is the hit.
_Avoid_: Power attack, heavy attack, charge shot

**Sword Beam**:
What a Charged Attack sends out along the Player's facing: a glowing copy of the blade that strikes the first thing in its way, for twice what a quick slash costs, and breaks a Ward or a Shortcut's cracked wall. It flies a screen and a half, and stops at the first thing it strikes or at the world's terrain.
_Avoid_: Projectile, wave, shot

**Ranged Attack**:
The button that throws the held Sub Weapon: V, or B / Circle on a gamepad. Each press throws one, along the Player's facing, without stopping them; it does nothing with no Sub Weapon held or none left to throw, while the Player is held still, or while the last one thrown is still out.
_Avoid_: Throw button, sub-weapon button, shoot
