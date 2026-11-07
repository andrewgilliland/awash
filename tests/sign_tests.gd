extends RefCounted

# A Sign: something in a Room the Player looks at with Interact, which shows its few lines in the
# Dialogue box. The lake's sealed temple door is one.

const SIGN_PATH := "res://scenes/world/sign.tscn"
const DIALOGUE_BOX := preload("res://scenes/ui/dialogue_box.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const LAKE_SCENE := preload("res://scenes/rooms/undertow_7.tscn")
const TILE := 16
# The lake's door, in columns, and what Vael makes of it.
const DOOR_COLUMNS := Vector2i(0, 2)
const DOOR_LINES := ["The door is sealed tight.", "Something on the other side is waiting."]

# Needs a root that is already in the tree: the Sign finds the Dialogue box through its group.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Using a Sign shows its lines in the Dialogue box, in its speaker's name", _test_reads],
		["Using a Sign while the Dialogue box is open does nothing", _test_busy],
		["The lake's sealed door is a Sign that says it is sealed", _test_lake_door],
	]


func _test_reads() -> bool:
	var board := _sign()
	if board == null:
		return false
	var player := PLAYER_SCENE.instantiate()
	_root.add_child(player)
	var box := DIALOGUE_BOX.instantiate()
	_root.add_child(box)
	board.get_node("Interactable").call("use", player)
	var valid: bool = box.call("is_open")
	valid = valid and (box.get_node("%Speaker") as Label).text == "???"
	var dialogue: Object = box.get("dialogue")
	valid = valid and dialogue != null
	if valid:
		dialogue.call("step", 10.0)
		box.call("_process", 0.0)
		valid = (box.get_node("%Text") as Label).text == "First."
		box.call("advance")
		box.call("advance")
		box.call("_process", 10.0)
		valid = valid and (box.get_node("%Text") as Label).text == "Second."
	box.free()
	board.free()
	player.free()
	return valid


func _test_busy() -> bool:
	var board := _sign()
	if board == null:
		return false
	var player := PLAYER_SCENE.instantiate()
	_root.add_child(player)
	var box := DIALOGUE_BOX.instantiate()
	_root.add_child(box)
	box.call("show_lines", [["MARA", "Hold on."]])
	board.get_node("Interactable").call("use", player)
	var valid := (box.get_node("%Speaker") as Label).text == "MARA"
	box.free()
	board.free()
	player.free()
	return valid


func _test_lake_door() -> bool:
	var room := LAKE_SCENE.instantiate()
	var door := room.get_node_or_null("DoorSign") as Node2D
	var valid := door != null and door.scene_file_path == SIGN_PATH
	if valid:
		valid = door.get("speaker") == "???"
		valid = valid and Array(door.get("lines")) == DOOR_LINES
		var column := int(door.position.x / TILE)
		valid = valid and column >= DOOR_COLUMNS.x and column <= DOOR_COLUMNS.y
	room.free()
	return valid


# A Sign of two lines in Vael's name, in the tree.
func _sign() -> Node2D:
	if not ResourceLoader.exists(SIGN_PATH):
		return null
	var board := (load(SIGN_PATH) as PackedScene).instantiate() as Node2D
	board.set("speaker", "???")
	board.set("lines", PackedStringArray(["First.", "Second."]))
	_root.add_child(board)
	return board
