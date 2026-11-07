extends RefCounted

# A Cache: a hidden spot holding Supplies, opened with Interact, empty once taken for the Run.
# Opened, it spills what it holds out as pickups for the Player to take. The Undertow's first
# waits in the wreck at its dead end.

const ROOM_PATH := "res://scenes/rooms/undertow_5.tscn"
const ROOM_ID := &"undertow_5"
const CACHE_ID := &"wreck_chest"
const BRINECAP := &"brinecap"
const HOLDS := 2
const CARRY_LIMIT := 9
const INTERACTABLE_SCRIPT := preload("res://scripts/world/interactable.gd")
const SHEET := "res://assets/packs/underwater/sunken_treasures.png"
# Tidefen's bomb crate: a Cache holding Bombs, under the stilt houses.
const VILLAGE_PATH := "res://scenes/rooms/tidefen_village_1.tscn"
const VILLAGE_ID := &"tidefen_village_1"
const CRATE_ID := &"bomb_crate"
const CRATE_SHEET := "res://assets/world/bomb_crate.png"
const BOMB := &"bomb"
const BOMBS_HELD := 5
const PICKUP_SCRIPT := preload("res://scripts/items/supply_pickup.gd")

# Needs a root that is already in the tree: a Room reads the Run in _ready.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["A Cache stands shut in the wreck, reached with Interact", _test_shut],
		["Opening a Cache spills its Supplies, and the Run remembers it empty", _test_opens],
		["A Cache taken this Run stays empty", _test_stays_empty],
		["A Cache stays shut while the Player has no room for its Supplies", _test_no_room],
		["Tidefen's bomb crate stands shut in the village, holding 5 Bombs", _test_crate_shut],
		["Opening the bomb crate spills its Bombs, taken as a Sub Weapon", _test_crate_opens],
	]


func _test_shut() -> bool:
	var room := _room()
	var cache := room.get_node_or_null("Cache") as Node2D
	var valid: bool = cache != null and cache.get("cache_id") == CACHE_ID
	if valid:
		var interactable := cache.get_node_or_null("Interactable") as Area2D
		valid = interactable != null and interactable.get_script() == INTERACTABLE_SCRIPT
		valid = valid and not cache.call("is_open")
		var sprite := cache.get_node_or_null("Sprite2D") as Sprite2D
		valid = valid and sprite != null and sprite.texture.resource_path == SHEET
	_close(room)
	return valid


func _test_opens() -> bool:
	var room := _room()
	var run := _root.get_node("RunState")
	var player := room.get_node("Player")
	var cache := room.get_node("Cache")
	var before: int = player.get("supplies").count(BRINECAP)
	var sprite := cache.get_node("Sprite2D") as Sprite2D
	var shut_frame := sprite.region_rect
	cache.get_node("Interactable").call("use", player)
	var spilled := _spilled(room, BRINECAP)
	var valid: bool = spilled.size() == HOLDS and _rising_apart(spilled)
	# Taken once they land, not straight from the Cache.
	valid = valid and player.get("supplies").count(BRINECAP) == before
	valid = valid and run.call("has_taken_cache", CACHE_ID) and cache.call("is_open")
	valid = valid and sprite.region_rect != shut_frame
	cache.get_node("Interactable").call("use", player)
	valid = valid and _spilled(room, BRINECAP).size() == HOLDS
	_close(room)
	return valid


func _test_stays_empty() -> bool:
	_root.get_node("RunState").call("start_run")
	_root.get_node("RunState").call("take_cache", CACHE_ID)
	var room := _room(false)
	var player := room.get_node("Player")
	var cache := room.get_node("Cache")
	var valid: bool = cache.call("is_open")
	cache.get_node("Interactable").call("use", player)
	valid = valid and _spilled(room, BRINECAP).is_empty()
	_close(room)
	return valid


func _test_no_room() -> bool:
	_root.get_node("RunState").call("start_run")
	_root.get_node("RunState").set("player_supplies", {BRINECAP: CARRY_LIMIT})
	var room := _room(false)
	var run := _root.get_node("RunState")
	var player := room.get_node("Player")
	var cache := room.get_node("Cache")
	cache.get_node("Interactable").call("use", player)
	var valid: bool = not cache.call("is_open") and not run.call("has_taken_cache", CACHE_ID)
	valid = valid and _spilled(room, BRINECAP).is_empty()
	_close(room)
	return valid


func _test_crate_shut() -> bool:
	var room := _room(true, VILLAGE_PATH, VILLAGE_ID)
	var crate := room.get_node_or_null("BombCrate") as Node2D
	var valid: bool = crate != null and crate.get("cache_id") == CRATE_ID
	if valid:
		valid = crate.get("kind") == BOMB and crate.get("count") == BOMBS_HELD
		valid = valid and not crate.call("is_open")
		var sprite := crate.get_node("Sprite2D") as Sprite2D
		valid = valid and sprite.texture.resource_path == CRATE_SHEET
	_close(room)
	return valid


func _test_crate_opens() -> bool:
	var room := _room(true, VILLAGE_PATH, VILLAGE_ID)
	var run := _root.get_node("RunState")
	var player := room.get_node("Player")
	var crate := room.get_node_or_null("BombCrate")
	var valid := crate != null
	if valid:
		crate.get_node("Interactable").call("use", player)
		var spilled := _spilled(room, BOMB)
		valid = spilled.size() == BOMBS_HELD and _rising_apart(spilled)
		for bomb in spilled:
			valid = valid and bomb.get("collect_method") == &"collect_sub_weapon"
		valid = valid and not player.get("sub_weapons").owns(BOMB)
		valid = valid and crate.call("is_open") and run.call("has_taken_cache", CRATE_ID)
	_close(room)
	return valid


# The pickups of a kind lying loose in the Room.
func _spilled(room: Node, kind: StringName) -> Array[Node]:
	var found: Array[Node] = []
	for node in room.get_children():
		if node.get_script() == PICKUP_SCRIPT and node.get("kind") == kind:
			found.append(node)
	return found


# Each pickup leaves the Cache upward, and no two fly the same way, so they land apart.
func _rising_apart(pickups: Array[Node]) -> bool:
	var ways := {}
	for pickup in pickups:
		var velocity: Vector2 = pickup.get("velocity")
		if velocity.y >= 0.0 or ways.has(velocity.x):
			return false
		ways[velocity.x] = true
	return true


func _room(new_run := true, path := ROOM_PATH, room_id := ROOM_ID) -> Node2D:
	var run := _root.get_node("RunState")
	if new_run:
		run.call("start_run")
	run.call("enter_room", room_id, &"west")
	if not ResourceLoader.exists(path):
		var empty := Node2D.new()
		_root.add_child(empty)
		return empty
	var room := (load(path) as PackedScene).instantiate() as Node2D
	_root.add_child(room)
	return room


func _close(room: Node) -> void:
	room.free()
	_root.get_node("RunState").call("start_run")
