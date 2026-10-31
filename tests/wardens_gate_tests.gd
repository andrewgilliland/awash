extends RefCounted

const ROOM_PATH := "res://scenes/rooms/waking_coast_7.tscn"
const WARDEN_ID := &"nameless_warden"
const WORLD_LAYER := 1 << 0
# The Gate stands across the road east, between the arena and the way on to Tidefen.
const ROOM_WIDTH := 160.0
const ARENA_FLOOR := 112.0

# Needs a root that is already in the tree: the Room reads the Run in _ready.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["The Nameless Warden holds the arena, a Gate shut behind it", _test_holds_the_arena],
		["Defeating the Warden opens the Gate, and the Run remembers", _test_defeat_opens_gate],
		["With the Warden defeated, the Room opens without it", _test_defeated_stays_gone],
	]


func _test_holds_the_arena() -> bool:
	var room := _room()
	var warden := room.get_node_or_null("NamelessWarden") as Node2D
	var gate := room.get_node_or_null("Gate") as StaticBody2D
	var east := room.get_node("Exits/east") as Node2D
	var valid := warden != null and gate != null
	if valid:
		valid = warden.position.x > ROOM_WIDTH / 2.0 and warden.position.y == ARENA_FLOOR
		valid = valid and warden.position.x < gate.position.x
		valid = valid and gate.position.x < east.position.x
		valid = valid and gate.collision_layer == WORLD_LAYER and _shut(gate)
	_close(room)
	return valid


func _test_defeat_opens_gate() -> bool:
	var room := _room()
	var run := _root.get_node("RunState")
	var warden := room.get_node("NamelessWarden")
	var gate := room.get_node("Gate") as StaticBody2D
	var player := room.get_node("Player")
	warden.emit_signal(&"defeated", 100)
	var valid: bool = run.call("has_defeated_boss", WARDEN_ID)
	valid = valid and player.get("level").experience == 100
	# It dissolves once the Warden has faded.
	gate.call("_process", 0.5)
	valid = valid and _shut(gate)
	gate.call("_process", 10.0)
	valid = valid and not _shut(gate) and not gate.visible
	_close(room)
	return valid


func _test_defeated_stays_gone() -> bool:
	_root.get_node("RunState").call("defeat_boss", WARDEN_ID)
	var room := _room(false)
	var warden := room.get_node_or_null("NamelessWarden")
	var gate := room.get_node("Gate") as StaticBody2D
	var valid := (warden == null or warden.is_queued_for_deletion()) and not _shut(gate)
	_close(room)
	return valid


func _room(new_run: bool = true) -> Node2D:
	var run := _root.get_node("RunState")
	if new_run:
		run.call("start_run")
	run.call("enter_room", &"waking_coast_7", &"west")
	var room := (load(ROOM_PATH) as PackedScene).instantiate() as Node2D
	_root.add_child(room)
	return room


func _shut(gate: StaticBody2D) -> bool:
	var shape := gate.get_node("Shape") as CollisionShape2D
	return not shape.disabled and gate.visible


func _close(room: Node) -> void:
	room.free()
	_root.get_node("RunState").call("start_run")
