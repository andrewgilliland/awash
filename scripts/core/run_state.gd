extends Node

const Equipment := preload("res://scripts/items/equipment.gd")
const SaveFile := preload("res://scripts/core/save_file.gd")
const World := preload("res://scripts/core/world.gd")

const FIRST_ROOM_ID := &"waking_coast_1"
const DEFAULT_ENTRY_ID := &"start"
# The Player's Health when the Run has nothing less to carry.
const FULL_HEALTH := -1
# The Saved Run's format: bumped whenever what it holds changes, so an older one is refused.
const SAVE_VERSION := 1
const SAVE_PATH := "user://run.json"
# Where a test run keeps its Saved Run instead, clear of the player's own.
const TEST_SAVE_PATH := "user://test_run.json"
# Each part of a Saved Run, and the JSON type it is kept as; numbers come back as floats.
const SAVED_FIELDS := {
	"room": TYPE_STRING,
	"entry": TYPE_STRING,
	"health": TYPE_FLOAT,
	"experience": TYPE_FLOAT,
	"supplies": TYPE_DICTIONARY,
	"armor": TYPE_STRING,
	"owned_armor": TYPE_ARRAY,
	"weapon": TYPE_STRING,
	"owned_weapons": TYPE_ARRAY,
	"sub_weapon": TYPE_STRING,
	"owned_sub_weapons": TYPE_ARRAY,
	"sub_weapon_counts": TYPE_DICTIONARY,
	"gold": TYPE_FLOAT,
	"rest_room": TYPE_STRING,
	"rest_entry": TYPE_STRING,
	"visited_rooms": TYPE_ARRAY,
	"defeated_bosses": TYPE_ARRAY,
	"opened_shortcuts": TYPE_ARRAY,
	"broken_walls": TYPE_ARRAY,
	"taken_caches": TYPE_ARRAY,
}

# Where the Saved Run is kept.
var save_path: String = SAVE_PATH
# Read-only for callers: the Room the Player is in and the Entry they came through.
var room_id: StringName = FIRST_ROOM_ID
var entry_id: StringName = DEFAULT_ENTRY_ID
# A new game from the start screen opens on the intro; a restarted Run does not.
var intro_pending: bool = false
# The Player's Health, carried from Room to Room; FULL_HEALTH until a hit lands.
var player_health: int = FULL_HEALTH
# The Player's total Experience this Run; their Level is read from it.
var player_experience: int = 0
# The Supplies the Player carries this Run, as Supplies.to_counts() gives them.
var player_supplies: Dictionary = {}
# The Armor the Player wears this Run, or &"" for none, and every Armor it owns.
var player_armor: StringName = Equipment.STARTING_ARMOR
var player_owned_armor: Array[StringName] = [Equipment.STARTING_ARMOR]
# The Weapon the Player holds this Run, and every Weapon it owns.
var player_weapon: StringName = Equipment.STARTING_WEAPON
var player_owned_weapons: Array[StringName] = [Equipment.STARTING_WEAPON]
# The Sub Weapon the Player holds this Run, or &"" for none, every one it owns, and how many of
# each it carries, as SubWeapons.to_counts() gives them.
var player_sub_weapon: StringName = &""
var player_owned_sub_weapons: Array[StringName] = []
var player_sub_weapon_counts: Dictionary = {}
# The Gold the Player carries this Run.
var player_gold: int = 0
# Where a defeat wakes the Player: the Rest point last rung this Run, or none yet (&"").
var rest_room_id: StringName = &""
var rest_entry_id: StringName = &""
var _visited_rooms: Dictionary = {FIRST_ROOM_ID: true}
# Every Boss defeated this Run, by id.
var _defeated_bosses: Dictionary = {}
# Every Shortcut opened this Run, by id.
var _opened_shortcuts: Dictionary = {}
# Every Breakable wall broken this Run, by id.
var _broken_walls: Dictionary = {}
# Every Cache taken this Run, by id.
var _taken_caches: Dictionary = {}


# The game runs on a plain SceneTree; one with a script of its own is a test run (or a tool),
# which must never touch the player's Saved Run. Decided here, before any Room can save.
func _init() -> void:
	var tree := Engine.get_main_loop()
	if tree != null and tree.get_script() != null:
		save_path = TEST_SAVE_PATH


# Begins a new Run: in the first Room at its default Entry, with only that Room visited.
func start_run() -> void:
	room_id = FIRST_ROOM_ID
	entry_id = DEFAULT_ENTRY_ID
	intro_pending = false
	player_health = FULL_HEALTH
	player_experience = 0
	player_supplies = {}
	player_armor = Equipment.STARTING_ARMOR
	player_owned_armor = [Equipment.STARTING_ARMOR]
	player_weapon = Equipment.STARTING_WEAPON
	player_owned_weapons = [Equipment.STARTING_WEAPON]
	player_sub_weapon = &""
	player_owned_sub_weapons = []
	player_sub_weapon_counts = {}
	player_gold = 0
	_visited_rooms = {FIRST_ROOM_ID: true}
	rest_room_id = &""
	rest_entry_id = &""
	_defeated_bosses = {}
	_opened_shortcuts = {}
	_broken_walls = {}
	_taken_caches = {}


# After a defeat the Run carries on: back at the Rest point last rung, or the first Room's
# default Entry before there is one, with full Health, keeping every Room visited, every Boss
# defeated, every Shortcut opened, every Breakable wall broken, every Cache taken, and all the
# Player's Experience, Supplies, Equipment and Gold.
func recover_from_defeat() -> void:
	room_id = _waking_room()
	entry_id = _waking_entry()
	intro_pending = false
	player_health = FULL_HEALTH
	_visited_rooms[room_id] = true


# Rings a Rest point: a defeat wakes the Player at this Room's Entry from now on.
func rest_at(rest_room: StringName, rest_entry: StringName) -> void:
	rest_room_id = rest_room
	rest_entry_id = rest_entry


func enter_room(next_room_id: StringName, next_entry_id: StringName) -> void:
	if next_room_id.is_empty() or next_entry_id.is_empty():
		push_error("Cannot enter Room '%s' at Entry '%s'." % [next_room_id, next_entry_id])
		return

	room_id = next_room_id
	entry_id = next_entry_id
	_visited_rooms[next_room_id] = true


func has_visited_room(visited_room_id: StringName) -> bool:
	return _visited_rooms.has(visited_room_id)


# A Boss stays defeated for the rest of the Run.
func defeat_boss(boss_id: StringName) -> void:
	_defeated_bosses[boss_id] = true


func has_defeated_boss(boss_id: StringName) -> bool:
	return _defeated_bosses.has(boss_id)


# A Shortcut stays open for the rest of the Run.
func open_shortcut(shortcut_id: StringName) -> void:
	_opened_shortcuts[shortcut_id] = true


func has_opened_shortcut(shortcut_id: StringName) -> bool:
	return _opened_shortcuts.has(shortcut_id)


# A Breakable wall stays broken for the rest of the Run.
func break_wall(wall_id: StringName) -> void:
	_broken_walls[wall_id] = true


func has_broken_wall(wall_id: StringName) -> bool:
	return _broken_walls.has(wall_id)


# A Cache stays empty for the rest of the Run.
func take_cache(cache_id: StringName) -> void:
	_taken_caches[cache_id] = true


func has_taken_cache(cache_id: StringName) -> bool:
	return _taken_caches.has(cache_id)


# Writes the Run to disk as the Saved Run, over any before it.
func save() -> bool:
	return SaveFile.write(save_path, to_saved())


# Whether there is a Saved Run that CONTINUE can take up.
func has_saved_run() -> bool:
	return _is_saved_run(SaveFile.read(save_path))


# Takes up the Saved Run, if there is one that can be read.
func continue_saved_run() -> bool:
	return restore(SaveFile.read(save_path))


# The Run as a Saved Run holds it: everything but the intro, ready for JSON. A Player saved as
# they fall is saved as the defeat will leave them.
func to_saved() -> Dictionary:
	var saved := _to_saved_as_is()
	if player_health == 0:
		saved.room = _waking_room()
		saved.entry = _waking_entry()
		saved.health = FULL_HEALTH
	return saved


func _to_saved_as_is() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"room": room_id,
		"entry": entry_id,
		"health": player_health,
		"experience": player_experience,
		"supplies": player_supplies.duplicate(),
		"armor": player_armor,
		"owned_armor": player_owned_armor.duplicate(),
		"weapon": player_weapon,
		"owned_weapons": player_owned_weapons.duplicate(),
		"sub_weapon": player_sub_weapon,
		"owned_sub_weapons": player_owned_sub_weapons.duplicate(),
		"sub_weapon_counts": player_sub_weapon_counts.duplicate(),
		"gold": player_gold,
		"rest_room": rest_room_id,
		"rest_entry": rest_entry_id,
		"visited_rooms": _visited_rooms.keys(),
		"defeated_bosses": _defeated_bosses.keys(),
		"opened_shortcuts": _opened_shortcuts.keys(),
		"broken_walls": _broken_walls.keys(),
		"taken_caches": _taken_caches.keys(),
	}


# Takes up a Saved Run, as to_saved() gave it and JSON returned it. One of another version,
# missing or mistyping any part, or in a Room the World no longer holds, is refused, and the Run
# is left as it was.
func restore(saved: Dictionary) -> bool:
	if not _is_saved_run(saved):
		return false
	room_id = StringName(saved.room)
	entry_id = StringName(saved.entry)
	intro_pending = false
	player_health = int(saved.health)
	player_experience = int(saved.experience)
	player_supplies = _counts(saved.supplies)
	player_armor = StringName(saved.armor)
	player_owned_armor = _names(saved.owned_armor)
	player_weapon = StringName(saved.weapon)
	player_owned_weapons = _names(saved.owned_weapons)
	player_sub_weapon = StringName(saved.sub_weapon)
	player_owned_sub_weapons = _names(saved.owned_sub_weapons)
	player_sub_weapon_counts = _counts(saved.sub_weapon_counts)
	player_gold = int(saved.gold)
	rest_room_id = StringName(saved.rest_room)
	rest_entry_id = StringName(saved.rest_entry)
	_visited_rooms = _set_of(saved.visited_rooms)
	_defeated_bosses = _set_of(saved.defeated_bosses)
	_opened_shortcuts = _set_of(saved.opened_shortcuts)
	_broken_walls = _set_of(saved.broken_walls)
	_taken_caches = _set_of(saved.taken_caches)
	return true


# Where a defeat wakes the Player: the Rest point last rung, or the first Room's default Entry.
func _waking_room() -> StringName:
	return FIRST_ROOM_ID if rest_room_id.is_empty() else rest_room_id


func _waking_entry() -> StringName:
	return DEFAULT_ENTRY_ID if rest_room_id.is_empty() else rest_entry_id


static func _is_saved_run(saved: Dictionary) -> bool:
	if not _is_number(saved.get("version")) or int(saved.version) != SAVE_VERSION:
		return false
	for field: String in SAVED_FIELDS:
		var value: Variant = saved.get(field)
		var type: int = SAVED_FIELDS[field]
		if type == TYPE_FLOAT:
			if not _is_number(value):
				return false
		elif type == TYPE_STRING:
			if not (value is String or value is StringName):
				return false
		elif typeof(value) != type:
			return false
		elif value is Array and not (value as Array).all(_is_name):
			return false
		elif value is Dictionary and not (value as Dictionary).values().all(_is_number):
			return false
	# CONTINUE loads the Room it was saved in, so the World must still hold it.
	return World.has_room(StringName(saved.room))


static func _is_number(value: Variant) -> bool:
	return value is int or value is float


static func _is_name(value: Variant) -> bool:
	return value is String or value is StringName


static func _names(values: Array) -> Array[StringName]:
	var names: Array[StringName] = []
	for value in values:
		names.append(StringName(value))
	return names


static func _counts(values: Dictionary) -> Dictionary:
	var counts := {}
	for key in values:
		counts[StringName(key)] = int(values[key])
	return counts


static func _set_of(values: Array) -> Dictionary:
	var ids := {}
	for value in values:
		ids[StringName(value)] = true
	return ids
