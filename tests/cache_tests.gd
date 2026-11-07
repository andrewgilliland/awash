extends RefCounted

# A Cache: a hidden spot holding Supplies, opened with Interact, empty once taken for the Run.
# Opened, it spills what it holds out as pickups for the Player to take. The Undertow passage's
# chest stands for them all; the wreck's chest at the dead end holds Scale Mail.

const ROOM_PATH := "res://scenes/rooms/undertow_3.tscn"
const ROOM_ID := &"undertow_3"
const CACHE_NODE := "Chest"
const CACHE_ID := &"passage_chest"
const KIND := &"mourning_salt"
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
# The wreck's chest: Scale Mail, under an id of its own, so a Run that took the Brinecaps it once
# held finds it shut again.
const WRECK_PATH := "res://scenes/rooms/undertow_5.tscn"
const WRECK_ID := &"undertow_5"
const MAIL_CACHE_ID := &"wreck_mail"
const SCALE_MAIL := &"scale_mail"

# Needs a root that is already in the tree: a Room reads the Run in _ready.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["A Cache stands shut in the passage, reached with Interact", _test_shut],
		["Opening a Cache spills its Supplies, and the Run remembers it empty", _test_opens],
		["A Cache taken this Run stays empty", _test_stays_empty],
		["A Cache stays shut while the Player has no room for its Supplies", _test_no_room],
		["Tidefen's bomb crate stands shut in the village, holding 5 Bombs", _test_crate_shut],
		["Opening the bomb crate spills its Bombs, taken as a Sub Weapon", _test_crate_opens],
		["The wreck's chest holds Scale Mail, under an id of its own", _test_wreck_holds_mail],
		["Opening the wreck's chest spills Scale Mail, taken as Armor", _test_wreck_opens],
		["The wreck's chest stays shut for a Player who owns Scale Mail", _test_wreck_owned],
	]


func _test_shut() -> bool:
	var room := _room()
	var cache := room.get_node_or_null(CACHE_NODE) as Node2D
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
	var cache := room.get_node(CACHE_NODE)
	var before: int = player.get("supplies").count(KIND)
	var sprite := cache.get_node("Sprite2D") as Sprite2D
	var shut_frame := sprite.region_rect
	cache.get_node("Interactable").call("use", player)
	var spilled := _spilled(room, KIND)
	var valid: bool = spilled.size() == HOLDS and _rising_apart(spilled)
	# Taken once they land, not straight from the Cache.
	valid = valid and player.get("supplies").count(KIND) == before
	valid = valid and run.call("has_taken_cache", CACHE_ID) and cache.call("is_open")
	valid = valid and sprite.region_rect != shut_frame
	cache.get_node("Interactable").call("use", player)
	valid = valid and _spilled(room, KIND).size() == HOLDS
	_close(room)
	return valid


func _test_stays_empty() -> bool:
	_root.get_node("RunState").call("start_run")
	_root.get_node("RunState").call("take_cache", CACHE_ID)
	var room := _room(false)
	var player := room.get_node("Player")
	var cache := room.get_node(CACHE_NODE)
	var valid: bool = cache.call("is_open")
	cache.get_node("Interactable").call("use", player)
	valid = valid and _spilled(room, KIND).is_empty()
	_close(room)
	return valid


func _test_no_room() -> bool:
	_root.get_node("RunState").call("start_run")
	_root.get_node("RunState").set("player_supplies", {KIND: CARRY_LIMIT})
	var room := _room(false)
	var run := _root.get_node("RunState")
	var player := room.get_node("Player")
	var cache := room.get_node(CACHE_NODE)
	cache.get_node("Interactable").call("use", player)
	var valid: bool = not cache.call("is_open") and not run.call("has_taken_cache", CACHE_ID)
	valid = valid and _spilled(room, KIND).is_empty()
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


func _test_wreck_holds_mail() -> bool:
	var room := _room(true, WRECK_PATH, WRECK_ID)
	var cache := room.get_node_or_null("Cache")
	var valid: bool = cache != null and cache.get("cache_id") == MAIL_CACHE_ID
	valid = valid and cache.get("kind") == SCALE_MAIL and cache.get("count") == 1
	_close(room)
	return valid


func _test_wreck_opens() -> bool:
	var room := _room(true, WRECK_PATH, WRECK_ID)
	var player := room.get_node("Player")
	var cache := room.get_node("Cache")
	cache.get_node("Interactable").call("use", player)
	var spilled := _spilled(room, SCALE_MAIL)
	var valid: bool = spilled.size() == 1 and cache.call("is_open")
	valid = valid and spilled[0].get("collect_method") == &"collect_armor"
	valid = valid and not player.get("equipment").owns_armor(SCALE_MAIL)
	_close(room)
	return valid


func _test_wreck_owned() -> bool:
	var run := _root.get_node("RunState")
	run.call("start_run")
	# A typed array, as the Run holds its Armor; a plain one would not take.
	var owned: Array[StringName] = [&"worn_leather_tunic", SCALE_MAIL]
	run.set("player_owned_armor", owned)
	var room := _room(false, WRECK_PATH, WRECK_ID)
	var player := room.get_node("Player")
	var cache := room.get_node("Cache")
	cache.get_node("Interactable").call("use", player)
	var valid: bool = not cache.call("is_open") and _spilled(room, SCALE_MAIL).is_empty()
	_close(room)
	return valid


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
