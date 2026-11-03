extends RefCounted

# A Cache: a hidden spot holding Supplies, opened with Interact, empty once taken for the Run.
# The Undertow's first waits in the wreck at its dead end.

const ROOM_PATH := "res://scenes/rooms/undertow_5.tscn"
const ROOM_ID := &"undertow_5"
const CACHE_ID := &"wreck_chest"
const BRINECAP := &"brinecap"
const HOLDS := 2
const CARRY_LIMIT := 9
const INTERACTABLE_SCRIPT := preload("res://scripts/world/interactable.gd")
const SHEET := "res://assets/packs/underwater/sunken_treasures.png"

# Needs a root that is already in the tree: a Room reads the Run in _ready.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["A Cache stands shut in the wreck, reached with Interact", _test_shut],
		["Opening a Cache gives its Supplies, and the Run remembers it empty", _test_opens],
		["A Cache taken this Run stays empty", _test_stays_empty],
		["A Cache stays shut while the Player has no room for its Supplies", _test_no_room],
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
	var valid: bool = player.get("supplies").count(BRINECAP) == before + HOLDS
	valid = valid and run.call("has_taken_cache", CACHE_ID) and cache.call("is_open")
	valid = valid and sprite.region_rect != shut_frame
	cache.get_node("Interactable").call("use", player)
	valid = valid and player.get("supplies").count(BRINECAP) == before + HOLDS
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
	valid = valid and player.get("supplies").count(BRINECAP) == 0
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
	valid = valid and player.get("supplies").count(BRINECAP) == CARRY_LIMIT
	_close(room)
	return valid


func _room(new_run := true) -> Node2D:
	var run := _root.get_node("RunState")
	if new_run:
		run.call("start_run")
	run.call("enter_room", ROOM_ID, &"west")
	if not ResourceLoader.exists(ROOM_PATH):
		var empty := Node2D.new()
		_root.add_child(empty)
		return empty
	var room := (load(ROOM_PATH) as PackedScene).instantiate() as Node2D
	_root.add_child(room)
	return room


func _close(room: Node) -> void:
	room.free()
	_root.get_node("RunState").call("start_run")
