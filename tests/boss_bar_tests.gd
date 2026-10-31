extends RefCounted

const ROOM_PATH := "res://scenes/rooms/waking_coast_7.tscn"
const HealthBar := preload("res://scripts/ui/health_bar.gd")
const FRAME := 1.0 / 60.0
const SCREEN := Vector2(160, 144)

# Needs a root that is already in the tree: the Room reads the Run in _ready.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["The Boss Health bar waits under the Pause menu for a Boss to wake", _test_waits],
		["While the Boss fights, its bar names it and fills to its Health", _test_fights],
		["The Boss Health bar hides once the Boss falls", _test_hides_on_defeat],
	]


func _test_waits() -> bool:
	var room := _room()
	var canvas := room.get_node("CanvasLayer")
	var bar := canvas.get_node_or_null("BossBar") as Control
	var menu := canvas.get_node_or_null("PauseMenu")
	var valid := bar is HealthBar and menu != null and bar.get_index() < menu.get_index()
	if valid:
		bar.call("_process", FRAME)
		valid = not bar.visible
	_close(room)
	return valid


func _test_fights() -> bool:
	var room := _room()
	var bar := _wake(room)
	var name := bar.get_node_or_null("Name") as Label
	var valid := bar.visible and name != null and name.text == "Nameless Warden"
	valid = valid and is_equal_approx(bar.call("fill_fraction"), 1.0)
	# Wide, along the bottom of the screen.
	valid = valid and bar.get_combined_minimum_size().x >= SCREEN.x * 0.75
	valid = valid and bar.position.y > SCREEN.y * 0.8
	valid = valid and bar.position.y + bar.get_combined_minimum_size().y <= SCREEN.y
	room.get_node("NamelessWarden").get("health").hurt(60, 0.0)
	for i in int((HealthBar.HOLD_TIME + HealthBar.DRAIN_TIME) / FRAME) + 2:
		bar.call("_process", FRAME)
	valid = valid and is_equal_approx(bar.call("fill_fraction"), 0.5)
	_close(room)
	return valid


func _test_hides_on_defeat() -> bool:
	var room := _room()
	var bar := _wake(room)
	var valid := bar.visible
	room.get_node("NamelessWarden").get("health").hurt(120, 0.0)
	bar.call("_process", FRAME)
	valid = valid and not bar.visible
	_close(room)
	return valid


# Brings the Player up to the Warden so it wakes, and lets the bar look.
func _wake(room: Node2D) -> Control:
	var warden := room.get_node("NamelessWarden") as Node2D
	(room.get_node("Player") as Node2D).global_position = warden.global_position - Vector2(50, 0)
	warden.call("_physics_process", FRAME)
	var bar := room.get_node("CanvasLayer/BossBar") as Control
	bar.call("_process", FRAME)
	return bar


func _room() -> Node2D:
	var run := _root.get_node("RunState")
	run.call("start_run")
	run.call("enter_room", &"waking_coast_7", &"west")
	var room := (load(ROOM_PATH) as PackedScene).instantiate() as Node2D
	_root.add_child(room)
	return room


func _close(room: Node) -> void:
	room.free()
	_root.get_node("RunState").call("start_run")
