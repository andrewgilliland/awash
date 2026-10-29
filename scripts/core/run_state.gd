extends Node

const Equipment := preload("res://scripts/items/equipment.gd")

const FIRST_ROOM_ID := &"waking_coast_1"
const DEFAULT_ENTRY_ID := &"start"
# The Player's Health when the Run has nothing less to carry.
const FULL_HEALTH := -1

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
# The Armor the Player wears this Run.
var player_armor: StringName = Equipment.STARTING_ARMOR
var _visited_rooms: Dictionary = {FIRST_ROOM_ID: true}


# Begins a new Run: in the first Room at its default Entry, with only that Room visited.
func start_run() -> void:
	room_id = FIRST_ROOM_ID
	entry_id = DEFAULT_ENTRY_ID
	intro_pending = false
	player_health = FULL_HEALTH
	player_experience = 0
	player_supplies = {}
	player_armor = Equipment.STARTING_ARMOR
	_visited_rooms = {FIRST_ROOM_ID: true}


# After a defeat the Run carries on: back at the first Room's default Entry with full Health,
# keeping every Room visited and all the Player's Experience, Supplies and Equipment.
func recover_from_defeat() -> void:
	room_id = FIRST_ROOM_ID
	entry_id = DEFAULT_ENTRY_ID
	intro_pending = false
	player_health = FULL_HEALTH
	_visited_rooms[FIRST_ROOM_ID] = true


func enter_room(next_room_id: StringName, next_entry_id: StringName) -> void:
	if next_room_id.is_empty() or next_entry_id.is_empty():
		push_error("Cannot enter Room '%s' at Entry '%s'." % [next_room_id, next_entry_id])
		return

	room_id = next_room_id
	entry_id = next_entry_id
	_visited_rooms[next_room_id] = true


func has_visited_room(visited_room_id: StringName) -> bool:
	return _visited_rooms.has(visited_room_id)
