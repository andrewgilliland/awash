extends RefCounted

# When the game saves the Run on its own: entering a Room, ringing a Rest point, and quitting.

const RunStateScript := preload("res://scripts/core/run_state.gd")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const BELL_SCENE := preload("res://scenes/world/rest_bell.tscn")
const PAUSE_MENU_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const FIRST_ROOM := preload("res://scenes/rooms/waking_coast_1.tscn")
# Where these tests keep their Saved Run, clear of the player's own.
const TEST_PATH := "user://test_saving.json"

# Needs a root that is already in the tree: Rooms find the Run there.
var _root: Window
var _run: Node
var _runner_path: String


func _init(root: Window) -> void:
	_root = root
	_run = root.get_node("RunState")


func get_tests() -> Array:
	return [
		["A test run keeps its Saved Run clear of the player's own", _test_runs_apart],
		["Entering a Room saves the Run", _test_room_saves],
		["Ringing a Rest point saves the Run, Rest point and all", _test_bell_saves],
		["Quit to Desktop saves the Run, then quits", _test_quit_saves],
		["Closing the window saves the Run", _test_close_saves],
	]


func _test_runs_apart() -> bool:
	var path: String = _run.get("save_path")
	return path != RunStateScript.SAVE_PATH and path == RunStateScript.TEST_SAVE_PATH


func _test_room_saves() -> bool:
	_begin()
	_run.call("enter_room", &"waking_coast_1", &"start")
	var room := FIRST_ROOM.instantiate()
	_root.add_child(room)
	var valid: bool = _run.call("has_saved_run")
	valid = valid and _saved().get("room") == "waking_coast_1"
	room.free()
	_end()
	return valid


func _test_bell_saves() -> bool:
	_begin()
	_run.call("enter_room", &"tidefen_village_1", &"west")
	_run.set("player_health", 10)
	var player := PLAYER_SCENE.instantiate()
	_root.add_child(player)
	var bell := BELL_SCENE.instantiate()
	_root.add_child(bell)
	bell.get_node("Interactable").call("use", player)
	var saved := _saved()
	var valid: bool = saved.get("rest_room") == "tidefen_village_1"
	valid = valid and saved.get("rest_entry") == "bell"
	valid = valid and saved.get("health") == float(player.get("health").maximum)
	bell.free()
	player.free()
	_end()
	return valid


func _test_quit_saves() -> bool:
	_begin()
	_run.set("player_gold", 12)
	var menu := PAUSE_MENU_SCENE.instantiate()
	_root.add_child(menu)
	var saved_at_quit := [false]
	menu.set("quit_game", func() -> void: saved_at_quit[0] = _saved().get("gold") == 12.0)
	(menu.get_node("%QuitButton") as Button).emit_signal(&"pressed")
	var valid: bool = saved_at_quit[0]
	menu.free()
	_end()
	return valid


func _test_close_saves() -> bool:
	_begin()
	_run.call("enter_room", &"waking_coast_1", &"start")
	var room := FIRST_ROOM.instantiate()
	_root.add_child(room)
	DirAccess.remove_absolute(TEST_PATH)
	_run.set("player_gold", 9)
	room.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	var valid: bool = _saved().get("gold") == 9.0
	room.free()
	_end()
	return valid


# Each test starts a fresh Run with no Saved Run, kept at TEST_PATH.
func _begin() -> void:
	_runner_path = _run.get("save_path")
	_run.set("save_path", TEST_PATH)
	DirAccess.remove_absolute(TEST_PATH)
	_run.call("start_run")


func _end() -> void:
	DirAccess.remove_absolute(TEST_PATH)
	_run.set("save_path", _runner_path)
	_run.call("start_run")
	_root.get_tree().paused = false


func _saved() -> Dictionary:
	var json := JSON.new()
	json.parse(FileAccess.get_file_as_string(TEST_PATH))
	return json.data if json.data is Dictionary else {}
