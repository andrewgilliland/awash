extends RefCounted

# Where the Dialogue box sits: at the foot of the screen, unless that would cover the Player or
# whoever is speaking, when it moves to the top. It picks its side as a conversation opens.

const SCREEN := Vector2i(160, 144)
const DIALOGUE_BOX := preload("res://scenes/ui/dialogue_box.tscn")
const VILLAGER_SCENE := preload("res://scenes/npcs/villager.tscn")
const MARA_SCENE := preload("res://scenes/npcs/mara.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
# The panel's top edge at the foot of the screen, and at the top.
const BOTTOM_Y := 98.0
const TOP_Y := 4.0
# Feet on screen: clear of both places the box can go, under the bottom one, under the top one.
const CLEAR_Y := 80.0
const LOW_Y := 112.0
const HIGH_Y := 30.0

# Needs a root that is already in the tree: the box finds the Player through its group.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["The Dialogue box moves to the top when it would cover the Player", _test_player_low],
		["The Dialogue box moves to the top when it would cover the speaker", _test_speaker_low],
		["The Dialogue box stays at the foot when the top would cover a talker too", _test_both],
		["The Next arrow moves with the Dialogue box", _test_arrow_follows],
		["The Dialogue box keeps its side until the conversation ends", _test_keeps_side],
		["A Villager keeps itself in view as it talks", _test_villager],
		["Mara keeps herself in view as she talks", _test_mara],
	]


func _test_player_low() -> bool:
	var player := _player(LOW_Y)
	var box := _box()
	box.call("show_lines", [["MARA", "Here."]])
	var valid := is_equal_approx(_panel_y(box), TOP_Y)
	box.free()
	player.free()
	return valid


func _test_speaker_low() -> bool:
	var player := _player(CLEAR_Y)
	var speaker := _speaker(LOW_Y)
	var box := _box()
	box.call("show_lines", [["MARA", "Here."]], speaker)
	var valid := is_equal_approx(_panel_y(box), TOP_Y)
	box.free()
	speaker.free()
	player.free()
	return valid


func _test_both() -> bool:
	var player := _player(HIGH_Y)
	var speaker := _speaker(LOW_Y)
	var box := _box()
	box.call("show_lines", [["MARA", "Here."]], speaker)
	var valid := is_equal_approx(_panel_y(box), BOTTOM_Y)
	box.free()
	speaker.free()
	player.free()
	return valid


# The Player's camera is held to one screen, so a Room position is also where it is drawn.
func _test_arrow_follows() -> bool:
	var player := _player(LOW_Y)
	var box := _box()
	var gap := _next_y(box) - _panel_y(box)
	box.call("show_lines", [["MARA", "Here."]])
	var valid := is_equal_approx(_next_y(box) - _panel_y(box), gap)
	valid = valid and is_equal_approx(_panel_y(box), TOP_Y)
	box.free()
	player.free()
	return valid


func _test_keeps_side() -> bool:
	var player := _player(LOW_Y)
	var box := _box()
	box.call("show_lines", [["MARA", "Here."], ["MARA", "Still here."]])
	player.position.y = CLEAR_Y
	box.call("advance")
	box.call("advance")
	box.call("_process", 0.1)
	var valid: bool = box.call("is_open") and is_equal_approx(_panel_y(box), TOP_Y)
	box.call("advance")
	box.call("advance")
	box.call("show_lines", [["MARA", "Again."]])
	valid = valid and is_equal_approx(_panel_y(box), BOTTOM_Y)
	box.free()
	player.free()
	return valid


func _test_villager() -> bool:
	var player := _player(CLEAR_Y)
	var villager := VILLAGER_SCENE.instantiate() as Node2D
	villager.set("speaker", "NETTER")
	villager.set("lines", PackedStringArray(["Mind the nets."]))
	villager.position = Vector2(100, LOW_Y)
	_root.add_child(villager)
	var box := _box()
	villager.get_node("Interactable").call("use", player)
	var valid: bool = box.call("is_open") and is_equal_approx(_panel_y(box), TOP_Y)
	box.free()
	villager.free()
	player.free()
	return valid


func _test_mara() -> bool:
	var player := _player(CLEAR_Y)
	var mara := MARA_SCENE.instantiate() as Node2D
	mara.position = Vector2(100, LOW_Y)
	_root.add_child(mara)
	var box := _box()
	mara.get_node("Interactable").call("use", player)
	var valid: bool = box.call("is_open") and is_equal_approx(_panel_y(box), TOP_Y)
	box.free()
	mara.free()
	player.free()
	return valid


func _player(feet_y: float) -> Node2D:
	var player := PLAYER_SCENE.instantiate() as Node2D
	player.position = Vector2(80, feet_y)
	var camera := player.get_node("Camera2D") as Camera2D
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = SCREEN.x
	camera.limit_bottom = SCREEN.y
	camera.position_smoothing_enabled = false
	_root.add_child(player)
	return player


func _speaker(feet_y: float) -> Node2D:
	var speaker := Node2D.new()
	speaker.position = Vector2(100, feet_y)
	_root.add_child(speaker)
	return speaker


func _box() -> Control:
	var box := DIALOGUE_BOX.instantiate() as Control
	_root.add_child(box)
	return box


static func _panel_y(box: Control) -> float:
	return (box.get_node("Panel") as Control).position.y


static func _next_y(box: Control) -> float:
	return (box.get_node("%Next") as Control).position.y
