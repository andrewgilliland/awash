# Player Behavior Spec

## Purpose

This spec defines the minimal player baseline while player behavior is rebuilt.

## Controls

- `move_left`: move horizontally to the left.
- `move_right`: move horizontally to the right.
- `jump`: jump while grounded.
- `melee_attack`: hold to charge, release to attack.

## Movement

- Horizontal input accelerates the player toward the configured movement speed.
- Releasing horizontal input applies friction until horizontal velocity reaches zero.
- Pressing jump while grounded applies the configured upward jump velocity.
- Gravity applies while the player is airborne.
- The player faces the most recent horizontal movement direction, except while facing is locked.
- Facing is locked during `CHARGE` and `ATTACK`.
- During `ATTACK`, friction slows horizontal velocity to zero, on the ground and in the air.

## States

- `IDLE`: selected while there is no horizontal input.
- `WALK`: selected while left or right input is held.
- `JUMP`: selected while airborne.
- `CHARGE`: selected while `melee_attack` is held; movement continues, facing is locked, and sword charge pose is shown. Charging works on the ground and in the air, and jumping while charging keeps the charge.
- `ATTACK`: selected when `melee_attack` is released after charging, on the ground or in the air, and held until the animation finishes. Jumping is not possible during `ATTACK`.
- When `ATTACK` finishes, the player returns to `IDLE` on the floor or `JUMP` in the air.
- State changes are decided once per physics frame, before the body moves, so a landing or ledge walk-off shows on the following frame.

## Damage

- The Player starts with 50 Health, counted in tens; each Level sets its maximum (see Growth). A hit from an enemy hitbox costs its damage, less the Armor's Defense: 10 for a Scavenger's spear, 15 for a Storm Wisp's arc in the Worn Leather Tunic. Five spear hits defeat it, or four arcs.
- A hit that lands knocks the Player up and away from the hitbox (90 sideways, 120 up) and takes control away for 0.3 seconds: walk, jump and melee input are ignored, a charge or attack is lost, and the Player shows `JUMP` while tumbling.
- After a hit the Player is invulnerable for 1 second and blinks; hits during that time cost nothing.
- The Player's Health carries from Room to Room; only a defeat or a new Run refills it.
- At 0 Health the Player is defeated. It stops answering the controls, falls where it lands and flickers. Then it wakes at the first Room's `start` Entry with full Health, and the Run, its visited Rooms and its Map carry on.
- The sword's hitbox is live only during `ATTACK`, 12 pixels in front of the Player by facing. A quick Attack costs an enemy 10 Health plus the Player's Strength; a Charged Attack, let go after 0.5 seconds of `CHARGE`, costs twice that, 20 at Strength 0. Once the Charge is full the sword blinks bright every 0.08 seconds until it is let go.

## Growth

- Every enemy defeated in a Room earns the Player that enemy's Experience, every time, even one that has come back: 10 for a Scavenger, 15 for a Storm Wisp, 20 for a Wraith.
- The Player's Level is read from its total Experience against the Level table in `scripts/player/level.gd`. Each row gives the total Experience that reaches the Level and its maximum Health and Strength, in tens; the last row is the highest Level.

  | Level | Total Experience | Max Health | Strength |
  |---|---|---|---|
  | 1 | 0 | 50 | 0 |
  | 2 | 40 | 60 | 0 |
  | 3 | 100 | 70 | 0 |
  | 4 | 180 | 80 | 0 |
  | 5 | 300 | 90 | 10 |

- One defeat can raise more than one Level. Past the highest Level, Experience still counts but raises nothing.
- Reaching a Level raises the Health left by as much as the maximum rose; it is not a refill. Defeated Health stays defeated.
- Reaching a Level plays `level_up` and shows LEVEL UP over the Player, rising 10 pixels and fading over 1 second, without pausing play. Near a screen edge it sits inside the screen rather than centred on the Player.
- The Run carries the total Experience from Room to Room and through a defeat; only a new Run resets it.
- The Stats Panel shows the Level, Experience out of the total for the next Level (or `MAX` at the highest), Health and Strength.

## Supplies

- A defeated enemy may leave a Brinecap where it fell: a Scavenger one time in four (25%), a Storm Wisp 20%, a Wraith 35%, rolled on every defeat. The Room adds it on its next physics step; it falls to the ground, glints every second, and is lost if it falls for 3 seconds without landing. It is gone when the Player leaves the Room.
- The Player collects a Brinecap by touching it, with the `pickup` sound. It carries up to 9 of each kind of Supply (`scripts/items/supplies.gd`); one it has no room for stays where it lies.
- Supplies are used from the Pause menu's Inventory, with play paused: choosing a row eats one of that kind. A Brinecap restores 10 Health, up to the maximum, with the `eat` sound (which plays through the pause), and the menu stays open on the row. At full Health nothing is spent and `Health is full` shows under the list for 1.2 seconds; with none carried, held still or defeated nothing happens.
- The Run carries the Supplies from Room to Room and through a defeat; only a new Run empties them.
- The Inventory sits second in the Pause menu, after Stats. Like every Panel, it has no title of its own (its tab names it) and its content starts at the top; only the Map heads its Panel, with the Region's name. It lists each kind carried as a row, its name on the left and how many on the right, or says `No Supplies carried`. Down from its tab runs through the rows to Resume, and up runs back; using the last of a kind removes its row and returns focus to the tab.

## Equipment

- The Player has one Equipment slot so far, Armor. A new Run owns and wears the Worn Leather Tunic; the slot can be emptied, which leaves no Defense. `scripts/items/equipment.gd` declares every Armor with its name, Defense and 8x8 icon (`assets/sprites/items/worn_leather_tunic.aseprite`), and holds the Armor owned and the one worn.
- Defense is the Health the Armor takes off each hit that lands. A hit Defense lowers still costs at least 5, and a weaker hit costs what it is. The Worn Leather Tunic has Defense 0, so it changes nothing.
- The Run carries the Armor owned and the one worn, or none, from Room to Room and through a defeat; only a new Run puts the Worn Leather Tunic back on.
- The Equipment Panel's Armor row shows `Armor` on the left and the piece worn on the right with its icon, or `None`. While the Armor row or its list has focus, the list under it shows every Armor owned with its icon, the worn one marked `Worn`; down from the Armor row moves into it. Choosing an Armor puts it on, choosing the one worn takes it off, and focus returns to the Armor row. Stats shows the Defense after Strength.

## Sound

- Sounds play on the `SFX` audio bus (`default_bus_layout.tres`), from `AudioStreamPlayer`s under the Player's `Sounds` node.
- `jump` plays when the jump impulse is applied, not when the Player walks off a ledge or is knocked into the air.
- `land` plays on returning to `IDLE` or `WALK` from `JUMP` after at least 0.08 seconds in the air, so appearing at an Entry lands quietly.
- `swing` plays when `ATTACK` begins, and `hit` when the sword strikes a Hurtbox.
- `level_up` plays on reaching a Level, `pickup` on collecting a Supply and `eat` on using one.
- `hurt` plays when a hit lands, or `defeat` instead when it takes the last Health; the Room waits 1.2 seconds, to see the Player fall and hear the sound, before it moves the Player back to the start.
- The sounds are chiptune effects made by `scripts/tools/make_sfx.py` into `assets/audio/sfx/`; change them there and rerun it.

## Animation

- The Player rig's table in `scripts/player/player_rig.gd` declares the sheets (`player_1.png` and `weapons/sword_1.png`, 16x16 cells in one row), each animation's frames, speed and looping, the per-frame sword offsets, and what each state shows.
- Idle, Walk, Jump and Attack each show their own body animation.
- Jump plays once and holds its final frame while airborne; Attack plays once, and its end finishes the `ATTACK` state.
- While charging, the body shows `walk` when horizontal input is held and `idle` otherwise.
- The sword shows only during `CHARGE` and `ATTACK`, with its own `charge` and `attack` animations.
- Each sword frame sits at its declared offset from the body, and the body and sword mirror with facing.
- A shown animation keeps playing, even across a state change that still shows it (Walk into a moving Charge); a newly shown animation starts from its first frame.

## Ownership

- `scripts/player/player_controller.gd` (the Player controller) owns the Movement and States rules: state transitions, facing, horizontal velocity and the jump impulse.
- `scripts/player/player_rig.gd` (the Player rig) owns the Animation rules and their table.
- `scripts/player/player.gd` (the Player body) owns gravity, `move_and_slide` and reading `Input`, and hands each step's state, facing and movement to the rig. It owns the Player's Health, Level, Supplies and Equipment, takes the Armor's Defense off each hit, collects and uses Supplies, turns Experience into Levels, Health and the sword's hit, turns a hurtbox hit into the controller's knockback, keeps the sword hitbox live during `ATTACK`, and reports defeat.
- `scripts/player/player_controller.gd` also owns knockback and the stun that follows a hit.
- `scripts/player/level.gd` (the Level) owns the Level table and reads a Level and its stats from total Experience.
- `scripts/core/main.gd` (the Room) adds the Health bar under its Pause menu, hands each of its enemies' defeats to the Player as Experience, rolls each one's drop chance and adds the Brinecap it leaves, and returns the Player to the start when it is defeated. `scripts/core/run_state.gd` carries the Player's Health, Experience, Supplies and Armor between Rooms and recovers the Run from a defeat.
- `scripts/ui/health_bar.gd` (the Health bar) fills to the share of the Player's Health left, in the top-left corner. A hit drops the fill at once, and a trail of the lost Health holds for 0.15 seconds, then drains over 0.5. `scripts/ui/stats_view.gd` shows the Level, Experience, `Health current / maximum`, Strength and Defense on the Stats Panel, names on the left and values on the right. `scripts/ui/level_up_flash.gd` shows LEVEL UP over the Player. `scripts/items/supply_pickup.gd` is a Supply lying in a Room (`scenes/items/brinecap.tscn`); `scripts/ui/inventory_view.gd` lists Supplies on the Inventory and uses the one chosen; `scripts/ui/equipment_view.gd` shows each Equipment slot and its piece; `scripts/ui/pause_menu.gd` links focus down through its rows.
- `scripts/player/player_sounds.gd` (the Player sounds) owns which state changes make a sound and plays sounds by name; the Player body hands it the controller's state changes and jumps, the sword's strikes and its own hits.

## Out Of Scope

All other player behavior, including running, guarding and projectiles, will be added separately.
