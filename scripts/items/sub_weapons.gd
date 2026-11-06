extends RefCounted

# The Sub Weapons the Player has in a Run: the one held, if any, which Ranged Attack uses, every
# one owned, and how many of each are carried, up to the carry limit.

const BOMB := &"bomb"
# Every Sub Weapon: its name, what is shown over the Player when it is first found, a description
# of two lines at most, its 8x8 icon, and the scene Ranged Attack sends out.
const KINDS := {
	BOMB:
	{
		name = "Bomb",
		found = "BOMBS",
		description = "A fisher's clay Bomb. Bursts for 20 after a short fuse.",
		icon = "res://assets/items/bomb.png",
		scene = "res://scenes/items/bomb.tscn",
	},
}
# What the Sub Weapon slot reads with nothing held.
const NONE := "None"
# The most of any one Sub Weapon the Player can carry.
const CARRY_LIMIT := 9

# Read-only for callers: change them through own() and hold(). The Sub Weapon held, or &"" for
# none, and every one owned, in the order found.
var held: StringName = &""
var owned: Array[StringName] = []
var _counts: Dictionary = {}


# Starts from what the Run carried. Unknown kinds are dropped, whatever is held is owned, and
# counts are held to the limit.
func _init(held_id: StringName = &"", owned_ids: Array = [], counts: Dictionary = {}) -> void:
	for id: StringName in owned_ids:
		own(id)
	if KINDS.has(held_id):
		own(held_id)
		held = held_id
	for id: StringName in counts:
		if owns(id):
			_counts[id] = clampi(counts[id], 0, CARRY_LIMIT)


# Owns a known Sub Weapon not owned yet, and returns whether it did.
func own(id: StringName) -> bool:
	if not KINDS.has(id) or owns(id):
		return false
	owned.append(id)
	return true


func owns(id: StringName) -> bool:
	return owned.has(id)


# Takes up a Sub Weapon the Player owns, or none (&""), and returns whether it could.
func hold(id: StringName) -> bool:
	if not id.is_empty() and not owns(id):
		return false
	held = id
	return true


func held_name() -> String:
	return KINDS[held].name if not held.is_empty() else NONE


# Carries one more of an owned Sub Weapon, and returns whether there was room.
# Tops up every owned Sub Weapon to as many as can be carried, as a rest does.
func refill() -> void:
	for id in owned:
		_counts[id] = CARRY_LIMIT


func add(id: StringName) -> bool:
	if not owns(id) or count(id) >= CARRY_LIMIT:
		return false
	_counts[id] = count(id) + 1
	return true


# Carries one fewer, and returns whether there was one to spend.
func spend(id: StringName) -> bool:
	if count(id) <= 0:
		return false
	_counts[id] = count(id) - 1
	return true


func count(id: StringName) -> int:
	return _counts.get(id, 0)


# The counts for the Run to carry: every Sub Weapon owned, and how many.
func to_counts() -> Dictionary:
	var counts := {}
	for id in owned:
		counts[id] = count(id)
	return counts
