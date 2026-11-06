# Player Behavior Spec

## Purpose

This spec defines the minimal player baseline while player behavior is rebuilt.

## Controls

- `move_left`: move horizontally to the left.
- `move_right`: move horizontally to the right.
- `jump`: jump while grounded.
- `melee_attack`: hold to charge, release to attack.
- `ranged_attack`: throw the held Sub Weapon, on the press itself.

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
- `CHARGE`: selected when `ATTACK` finishes with `melee_attack` still held. The Charge fills from the press, so it is full after 0.5 seconds of holding; let go before then and it just ends, with no second swing. While charging, movement continues, facing is locked, and sword charge pose is shown. Charging works on the ground and in the air, and jumping while charging keeps the charge.
- `ATTACK`: selected the moment `melee_attack` is pressed, a quick slash, or when a full Charge is let go, a Charged Attack; on the ground or in the air, and held until the animation finishes. Jumping is not possible during `ATTACK`.
- When `ATTACK` finishes, the player returns to `IDLE` on the floor or `JUMP` in the air.
- State changes are decided once per physics frame, before the body moves, so a landing or ledge walk-off shows on the following frame.

## Damage

- The Player starts with 50 Health, counted in tens; each Level sets its maximum (see Growth). A hit from an enemy hitbox costs its damage, less the Armor's Defense: 10 for a Scavenger's spear, 15 for a Storm Wisp's arc in the Worn Leather Tunic. Five spear hits defeat it, or four arcs.
- A hit that lands knocks the Player up and away from the hitbox (90 sideways, 120 up) and takes control away for 0.3 seconds: walk, jump and melee input are ignored, a charge or attack is lost, and the Player shows `JUMP` while tumbling.
- After a hit the Player is invulnerable for 1 second and blinks; hits during that time cost nothing.
- The Player's Health carries from Room to Room; only a defeat or a new Run refills it.
- At 0 Health the Player is defeated. It stops answering the controls, falls where it lands and flickers. Then it wakes at the first Room's `start` Entry with full Health, and the Run, its visited Rooms and its Map carry on.
- The sword's hitbox is live only during a quick slash's `ATTACK`, 12 pixels in front of the Player by facing, and costs an enemy 10 Health plus the Player's Strength and the Weapon's Attack. A Charged Attack's swing strikes nothing: it looses a Sword Beam from the blade, which flies along the Player's facing at 240 pixels a second for up to 240 pixels and costs the first thing it strikes twice a slash, 20 at Strength 0 with the Short Sword, charged, so it breaks a Ward or a Shortcut's cracked wall. It stops there, or at the world's terrain. Once the Charge is full the sword blinks bright every 0.08 seconds until it is let go, and the Charged Attack let go from it swings lit the whole way; a quick Attack's swing is plain.

## Growth

- Every enemy defeated in a Room earns the Player that enemy's Experience, every time, even one that has come back: 10 for a Scavenger, 15 for a Storm Wisp, 20 for a Wraith.
- The Player's Level is read from its total Experience against the Level table in `scripts/player/level.gd`. Each row gives the total Experience that reaches the Level and its maximum Health and Strength. Each Level raises Health by 10 and Strength by 5, and takes about half again the Experience of the last; the last row, Level 10, is the highest.

  | Level | Total Experience | Max Health | Strength |
  |---|---|---|---|
  | 1 | 0 | 50 | 0 |
  | 2 | 40 | 60 | 5 |
  | 3 | 100 | 70 | 10 |
  | 4 | 180 | 80 | 15 |
  | 5 | 300 | 90 | 20 |
  | 6 | 450 | 100 | 25 |
  | 7 | 650 | 110 | 30 |
  | 8 | 900 | 120 | 35 |
  | 9 | 1200 | 130 | 40 |
  | 10 | 1600 | 140 | 45 |

- One defeat can raise more than one Level. Past the highest Level, Experience still counts but raises nothing.
- Reaching a Level raises the Health left by as much as the maximum rose; it is not a refill. Defeated Health stays defeated.
- Reaching a Level plays `level_up` and shows LEVEL UP over the Player, with what it raised beneath (`HP +10  STR +5`, added up when one gain reaches several Levels), rising 10 pixels and fading over 1 second, without pausing play. Near a screen edge it sits inside the screen rather than centred on the Player.
- The Run carries the total Experience from Room to Room and through a defeat; only a new Run resets it.
- The Stats Panel shows the Level, Experience out of the total for the next Level (or `MAX` at the highest), Health, Strength, Attack and Defense.

## Supplies

- A defeated enemy may leave a Supply where it fell, rolled on every defeat: a Scavenger a Brinecap one time in four (25%), a Storm Wisp a Brinecap 20%, a Wraith a Mourning Salt 35%, a Lurelight a Glowroe 20%. An enemy names its Supply as `DROP`, a Brinecap if it names none. The Room adds it on its next physics step; it falls to the ground, glints every second, and is lost if it falls for 3 seconds without landing. It is gone when the Player leaves the Room.
- The Player collects a dropped Supply by touching it, with the `pickup` sound. It carries up to 9 of each kind of Supply (`scripts/items/supplies.gd`); one it has no room for stays where it lies.
- Supplies are used from the Pause menu's Inventory, with play paused: choosing a row eats one of that kind. A Brinecap restores 10 Health and a Glowroe 20; a Mourning Salt restores half of max Health, rounded down, so it restores more as Levels raise it. Each heals up to the maximum, with the `eat` sound (which plays through the pause), and the menu stays open on the row. At full Health nothing is spent and `Health is full` takes the description strip's place, in yellow, for 1.2 seconds; with none carried, held still or defeated nothing happens.
- The Run carries the Supplies from Room to Room and through a defeat; only a new Run empties them.
- The Inventory sits second in the Pause menu, after Stats. Like every Panel, it has no title of its own (its tab names it) and its content starts at the top; only the Map heads its Panel, with the Region's name. It lists each kind carried as a row, its name on the left and how many on the right, or says `No Supplies carried`. Down from its tab runs through the rows to Resume, and up runs back; using the last of a kind removes its row and returns focus to the tab. A strip of up to two lines at the Panel's foot, under a divider, describes the focused kind (`scripts/items/supplies.gd` holds each description) and is empty on the tab and Resume.

## Equipment

- The Player has three Equipment slots, Weapon, Armor and Sub Weapon. A Weapon's Attack adds to each hit it lands: the Short Sword, which a new Run holds, adds 0, and the Oathblade adds 5. The Weapon slot is never empty, and the Run carries the Weapon held and the Weapons owned, through a defeat too. A new Run owns and wears the Worn Leather Tunic; the Armor slot can be emptied, which leaves no Defense. `scripts/items/equipment.gd` declares every Weapon with its name, Attack, 8x8 icon (`assets/items/short_sword.aseprite`, `assets/items/oathblade.aseprite`) and the sheet the sword in hand and its Sword Beam are drawn from (`assets/player/sword_1.png`, `assets/player/oathblade.aseprite`), and every Armor with its name, Defense and icon (`assets/items/worn_leather_tunic.aseprite`), and holds the pieces owned and the ones equipped.
- Defense is the Health the Armor takes off each hit that lands. A hit Defense lowers still costs at least 5, and a weaker hit costs what it is. The Worn Leather Tunic has Defense 0, so it changes nothing.
- The Run carries the Armor owned and the one worn, or none, from Room to Room and through a defeat; only a new Run puts the Worn Leather Tunic back on.
- The Equipment Panel is split by a divider. Above it, a row per slot shows `Weapon` or `Armor` on the left and the piece equipped on the right with its icon, or `None`, then `ATK` and the Attack on the left of one line and `DEF` and the Defense on its right. Below it are the pieces owned for the slot last focused (the Weapon when the Panel opens), each with its icon, the equipped one marked `Equipped`; the Armor's and the Sub Weapon's start with `None`. Down from the tab runs Weapon, Armor, Sub Weapon, Resume. Choosing a slot moves focus onto its equipped piece, the slot staying lit; while an Armor is focused, `DEF now > then` previews it, and while a Weapon is focused `ATK now > then`. Choosing a piece equips it, `None` takes the Armor off or puts the Sub Weapon away, choosing the one equipped changes nothing, and each goes back to the slot, as does up from the top piece. A strip of up to two lines at the Panel's foot, under a divider, describes the piece a focused slot holds or the piece focused (`scripts/items/equipment.gd` holds each description); it is empty on None, the tab and Resume. Stats shows the Attack, then the Defense, after Strength.
- A defeated Wraith may leave the Oathblade, on a 10% roll of its own after the one for its Mourning Salt, until the Player owns it. It lies 8 pixels to the right of where the Wraith fell, glints and falls like a Supply, and is gone when the Player leaves the Room. Touching it owns and holds it, with the `pickup` sound, and `GOT OATHBLADE` rises over the Player the way `LEVEL UP` does.
- A new Run owns no Sub Weapon and holds none. `scripts/items/sub_weapons.gd` declares every Sub Weapon with its name, the word shown when it is found, its 8x8 icon and the scene Ranged Attack throws, and holds the one held, the ones owned, and how many of each are carried, up to 9; the Run carries all three, through a defeat too. Tidefen's bomb crate, a Cache on the fishers' pier, holds 5 Bombs: the first Bomb collected owns and holds the Bomb, and `GOT BOMBS` rises over the Player.
- Ranged Attack throws the held Sub Weapon from 6 pixels in front of the Player and 10 up, along its facing, spending one, with the `throw` sound. Nothing is thrown with none held or carried, while the Player is held still or defeated, or while the last one thrown is still out. While a Sub Weapon is held, its icon and how many are carried show under the Health bar.
- A Bomb (`scripts/items/bomb.gd`) leaves the hand at 100 pixels a second along the Player's facing and 160 up, falls under the world's gravity, bounces once off the world's terrain keeping 0.4 of its speed, then rests where it lands. Its fuse sputters for 1 second, then it bursts where it is: for 0.25 seconds its blast, a circle of 24 pixels, strikes every enemy Hurtbox in it for 20, charged, so it breaks a Ward or a Shortcut's cracked wall, and a blast, so it breaks a Breakable wall (`scripts/world/breakable_wall.gd`), and it never strikes the Player. Then it is gone. Its fuse hisses, and it booms as it bursts.

## Sound

- Sounds play on the `SFX` audio bus (`default_bus_layout.tres`), from `AudioStreamPlayer`s under the Player's `Sounds` node.
- `jump` plays when the jump impulse is applied, not when the Player walks off a ledge or is knocked into the air.
- `land` plays on returning to `IDLE` or `WALK` from `JUMP` after at least 0.08 seconds in the air, so appearing at an Entry lands quietly.
- `swing` plays when a slash begins, `beam` when a full Charge is let go and looses its Sword Beam, and `hit` when the sword strikes a Hurtbox.
- `level_up` plays on reaching a Level, `pickup` on collecting a Supply, Weapon or Sub Weapon, `eat` on using a Supply, and `throw` on throwing a Sub Weapon.
- `hurt` plays when a hit lands, or `defeat` instead when it takes the last Health; the Room waits 1.2 seconds, to see the Player fall and hear the sound, before it moves the Player back to the start.
- The sounds are chiptune effects made by `scripts/tools/make_sfx.py` into `assets/player/`; change them there and rerun it.

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
- `scripts/player/player.gd` (the Player body) owns gravity, `move_and_slide` and reading `Input`, and hands each step's state, facing and movement to the rig. It owns the Player's Health, Level, Supplies and Equipment, takes the Armor's Defense off each hit, collects and uses Supplies, collects and holds Weapons (the rig draws the sword from the held one's sheet), collects, holds and throws Sub Weapons, turns Experience into Levels, Health and the sword's hit, turns a hurtbox hit into the controller's knockback, keeps the sword hitbox live during a slash's `ATTACK`, looses a Charged Attack's Sword Beam (`scripts/player/sword_beam.gd`, whose hit is charged, which breaks a Ward), and reports defeat.
- `scripts/player/player_controller.gd` also owns knockback and the stun that follows a hit.
- `scripts/player/level.gd` (the Level) owns the Level table and reads a Level and its stats from total Experience.
- `scripts/core/main.gd` (the Room) adds the Health bar and the Sub Weapon count under its Pause menu, hands each of its enemies' defeats to the Player as Experience, rolls each one's drop chance and adds the Supply it leaves, and returns the Player to the start when it is defeated. `scripts/core/run_state.gd` carries the Player's Health, Experience, Supplies, Equipment and Sub Weapons between Rooms and recovers the Run from a defeat.
- `scripts/ui/health_bar.gd` (the Health bar) fills to the share of the Player's Health left, in the top-left corner. A hit drops the fill at once, and a trail of the lost Health holds for 0.15 seconds, then drains over 0.5. `scripts/ui/stats_view.gd` shows the Level, Experience, `Health current / maximum`, Strength and Defense on the Stats Panel, names on the left and values on the right. `scripts/ui/level_up_flash.gd` shows LEVEL UP over the Player. `scripts/items/supply_pickup.gd` is a Supply lying in a Room (`scenes/items/brinecap.tscn`); `scripts/ui/inventory_view.gd` lists Supplies on the Inventory and uses the one chosen; `scripts/ui/equipment_view.gd` shows each Equipment slot and its piece; `scripts/ui/sub_weapon_count.gd` shows the held Sub Weapon's icon and count under the Health bar; `scripts/ui/pause_menu.gd` links focus down through its rows.
- `scripts/player/player_sounds.gd` (the Player sounds) owns which state changes make a sound and plays sounds by name; the Player body hands it the controller's state changes and jumps, the sword's strikes and its own hits.

## Out Of Scope

All other player behavior, including running, guarding and Sub Weapons other than the Bomb, will be added separately.
