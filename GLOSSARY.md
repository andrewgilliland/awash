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

**Interactable**:
Anything Interact can use, such as Mara. It reports being used and shows a bobbing arrow above itself while the Player is in reach; what using it does is up to its owner.
_Avoid_: Usable, trigger, hotspot

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

## World

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

**Rest point**:
A place in a Safe spoke where the Player recovers, and which a defeat returns them to without ending the Run.
_Avoid_: Checkpoint, save point, bonfire

**Background**:
The distant layers of a Region drawn behind its Rooms, each scrolling slower the farther back it is: for the Waking Coast, a sky with the sun and its beams fixed in it, clouds far and near, ships sailing on the horizon, and the sea. Every Room in the Region shows the same Background, set by where the Room sits in the world, so it carries on across Exits; the caves show a dark rock wall instead.
_Avoid_: Backdrop, skybox, parallax (as a thing)

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
A one-way route that returns the Player quickly to an earlier point on the Main path, such as the cracked wall between the Undertow and the sea cave. It stays shut from its far end until first used from its near end, unless a Breakable wall stands across its far end: the sea cave's rock opens it to a Bomb.
_Avoid_: Branch (for a one-way return), warp

**Drop**:
An Exit the Player falls through into a Room below, with no way back up. A sinkhole or a well is just what a Drop looks like.
_Avoid_: Pit, sinkhole, chute, hole (as the general term)

**Gate**:
A place on a route that stays shut until an ability unlock or a defeated Boss opens it, such as the ledge above the salt cliffs that double jump will reach, or the column of rune light across the trail east of the Warden's gate.
_Avoid_: Lock, barrier, door

**Breakable wall**:
Cracked rock across a route that only a Bomb's blast breaks; a sword's hit, quick or charged, knocks hollow off it. It crumbles as it breaks and stays broken for the Run. The rock at the sea cave's end, across the Shortcut, is one: it keeps the Undertow shut from the coast until the Player brings Bombs back from Tidefen, and breaking it opens the Shortcut.
_Avoid_: Bomb block, destructible wall, secret wall

**Cache**:
A hidden spot in a Room holding Supplies, or a Sub Weapon such as the Bombs in Tidefen's bomb crate, opened with Interact, that stays empty once taken for the Run. The first Bombs found are owned and taken up.
_Avoid_: Crate, chest, stash, pickup

**Supply**:
A consumable used in exploration or combat, such as a Restorative, bought at a Supply Shop, found in a Cache, or left where a defeated enemy fell. The Player carries up to 9 of each kind for the Run, and a defeat does not take them away.
_Avoid_: Item, consumable, loot (as the general term)

**Tide Draught**:
The first Restorative: a Supply that restores 20 Health.
_Avoid_: Potion, health potion

**Brinecap**:
A pale, salt-crusted mushroom from the coast's caves and tunnels: a Restorative that restores 10 Health. Scavengers and Storm Wisps forage it, so a defeated one sometimes leaves one where it fell, for the Player to collect by touch.
_Avoid_: Mushroom (as its name), food, snack

**Glowroe**:
A clutch of faintly glowing roe from the Undertow's pools: a Restorative that restores 20 Health. A defeated Lurelight sometimes leaves one where it fell.
_Avoid_: Eggs, caviar

**Mourning Salt**:
Salt wept from a Wraith's robes: a Restorative that restores half of the Player's max Health, rounded down, so it keeps its worth as Levels raise it. A defeated Wraith sometimes leaves one where it fell.
_Avoid_: Ectoplasm, soul salt

**Salvage**:
What the Player gathers from the wreck-strewn world and spends at shops. Defeated enemies drop it, Caches can hold it, and a defeat does not take it away.
_Avoid_: Gold, coins, money, currency

**Memory Relic**:
A rune that restores a flash of Vael's past when found, such as the one waiting in the rune alcove above the salt cliffs.
_Avoid_: Memory shard, flashback item

## Combat

**Health**:
How much more harm something can take, counted in tens. A plain hit costs 10; stronger ones, like a Storm Wisp's arc or a Charged Attack, cost more. Reaching 0 is defeat. The Player's carries from Room to Room for the whole Run.
_Avoid_: HP, hit points, life

**Health bar**:
The Player's Health on screen: a framed bar in the top-left corner, filled to the share of Health left. A hit drops the fill at once, and the Health it took lingers as a pale trail that drains away after it.
_Avoid_: HP bar, life bar, hearts

**Defeat**:
The Player's Health running out. Vael falls where he lands and stops answering the controls, then wakes at the first Room's start Entry with full Health, and later at the last Rest point he used. The Run carries on, keeping his Level, Experience and Supplies.
_Avoid_: Death, game over, dying

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

**Storm Wisp**:
The Waking Coast's flying enemy: a knot of mist and lightning that drifts over exposed heights. It crackles when the Player comes near, arcs lightning all around itself, then rests.
_Avoid_: Gas cloud, wisp (alone), spark

**Wraith**:
The Waking Coast's spirit enemy: a see-through oathkeeper that haunts the tunnels under the coast. The sword passes through it until it manifests and lashes out; then, for a moment, its Rune anchor shows and can be struck.
_Avoid_: Ghost, specter, phantom

**Rune anchor**:
The glowing stone lodged in a Wraith's chest, binding it to the coast. It is the only part of a Wraith the sword can hit, and only while it shows.
_Avoid_: Core, weak point, heart

**Lurelight**:
The Undertow's pool enemy: a fish lurking under the dark water, its lure a pale rune light. It drifts toward the Player, dims, then snaps straight up and lies stranded at the surface, open to a single hit.
_Avoid_: Angler, anglerfish, eel, lure fish

**Boss**:
An enemy that guards a Region's end, with its own Health bar along the bottom of the screen while it fights. Defeating it opens a Gate, and it stays defeated for the Run, through the Player's own defeat; a new Run brings it back.
_Avoid_: Miniboss, guardian (as the general term)

**Nameless Warden**:
The Waking Coast's Boss: an armored spirit with a blank stone mask and a salt-crusted shield, guarding the Warden's gate on the trail to Tidefen. It wakes when the Player crosses into the arena, then bashes with its shield and slams rune shockwaves along the floor, hurrying once half its Health is gone.
_Avoid_: Warden (alone), sentinel, guardian

**Ward**:
The Nameless Warden's guard of pale rune light. Quick Attacks glance off it; a Charged Attack, or a Bomb's blast, breaks it, and it returns after the Stagger.
_Avoid_: Shield, barrier, armor

**Stagger**:
The moments after a Ward breaks, when the Boss takes any hit and does not harm the Player by touch.
_Avoid_: Stun, daze

## Growth

**Level**:
How far the Player has grown in a Run, starting at 1. Enough Experience raises it, up to the highest Level, 10, and each Level raises the Player's maximum Health by 10 and Strength by 5.
_Avoid_: XP level, rank, character level, level (for a Room)

**Experience**:
What defeating an enemy earns the Player toward the next Level. Each kind of enemy is worth its own amount, every time it is defeated, even after it returns.
_Avoid_: XP, EXP, experience points

**Strength**:
The Player's own might, added to what each sword hit costs. Levels raise it; Equipment does not.
_Avoid_: Attack (the Player state), power, damage

## Equipment

**Equipment**:
What the Player wears or wields, one piece in each slot, kept for the whole Run rather than spent like a Supply. A defeat keeps it.
_Avoid_: Gear, outfit, loadout

**Weapon**:
The Equipment slot for what the Player wields: the sword each Attack swings, drawn in the Player's hand and in its Sword Beam. It is never empty; a new Run holds the Short Sword, and the Equipment Panel takes up any other Weapon owned.
_Avoid_: Blade, arm, main hand

**Short Sword**:
The Weapon Mara pulls from the sand on the Waking Coast and hands to Vael: a plain blade with Attack 0.
_Avoid_: Starting weapon, default weapon

**Oathblade**:
A ceremonial blade from the oathkeepers the Wraiths once were: a Weapon with Attack 5. A defeated Wraith sometimes leaves it where it fell, until the Player owns it; touching it takes it up at once.
_Avoid_: Wraith sword, ghost blade

**Attack** (of a Weapon):
What the Weapon held adds to each hit it lands, on top of the Player's Strength. Written `ATK` in the Equipment Panel.
_Avoid_: Damage, power, weapon strength

**Sub Weapon**:
The Equipment slot for what Ranged Attack throws, chosen in the Equipment Panel from the Sub Weapons the Player owns, or left empty. A new Run owns none. Unlike a Weapon, it is spent: the Player carries up to 9 of each, shown with its icon under the Health bar while it is held, and a defeat does not take them away.
_Avoid_: Secondary weapon, subweapon, ammo (as the slot)

**Bomb**:
A Tidefen fisher's clay Bomb: a Sub Weapon. Lobbed along the Player's facing, it bounces once and rests while its fuse sputters for a second, then bursts, striking every enemy within 24 pixels for 20, as a charged hit, so it breaks what a Sword Beam breaks, and as a blast, so it breaks a Breakable wall. Its blast never harms the Player. The bomb crate on Tidefen's pier, a Cache, holds the first 5.
_Avoid_: Grenade, explosive, powder keg

**Armor**:
The Equipment slot for what the Player wears, chosen in the Equipment Panel from the Armor the Player owns, or left empty for no Defense. A new Run owns and wears the Worn Leather Tunic.
_Avoid_: Armour, clothing, outfit

**Defense**:
How much Health the Player's Armor takes off each hit that lands. A hit always costs at least 5.
_Avoid_: AC, armor class, resistance, guard

**Worn Leather Tunic**:
The Armor Vael wakes in on the Waking Coast: sea-weathered leather that gives no Defense yet.
_Avoid_: Saltworn Leathers, starting armor, default armor

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
One page of the Pause menu, shown from when its menu button takes focus until another one does. Left and right move from Panel to Panel, round from the last to the first, and the Pause menu opens on the first.
_Avoid_: Tab, screen, page

**Inventory**:
The Panel listing each kind of Supply the Player carries and how many. Choosing one there uses it, with play paused: a Restorative restores its Health, and nothing is spent while Health is full.
_Avoid_: Supplies Panel, items menu, bag

**Equipment Panel**:
The Panel showing each Equipment slot with its piece above a divider, and below it the pieces owned for the slot last focused, the one equipped marked. Choosing a slot moves into its pieces; choosing one equips it, and None empties a slot that can be empty. Attack and Defense show above the divider, each with what it would become while a Weapon, or an Armor, is focused.
_Avoid_: Equip screen, gear menu, loadout

**Description**:
A line or two at the foot of the Inventory and the Equipment Panel saying what the focused Supply, or piece of Equipment, is. Each Supply and piece has its own.
_Avoid_: Tooltip, flavor text, help text

**Map**:
The Panel that draws each visited Room as a block, sized in screens and filled with its Region's colour, walled round with a gap at each Exit, marking any Rest point or Boss, with the name of the Region or Safe spoke the Player is in and a dot where the Player stands. Unvisited Rooms stay hidden, though a visited Room's Exits show the way on. Drawn for the whole World at once, as it is or as the Plan lays it out with Planned Rooms in outline, it is how the World's shape is seen before it is built.
_Avoid_: Minimap, world map, atlas
