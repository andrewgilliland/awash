extends RefCounted

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const PAUSE_MENU_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const FIRST_ROOM_SCENE := preload("res://scenes/rooms/waking_coast_1.tscn")
const SUPPLY_COUNT_PATH := "res://scenes/ui/supply_count.tscn"
const BRINECAP_SPRITE_PATH := "res://assets/sprites/items/brinecap.png"
const MENU_ROOT := "CenterContainer/MenuPanel/MarginContainer/VBoxContainer/"
const BRINECAP := &"brinecap"

# Needs a root that is already in the tree: the views find the Player through its group.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Equipment lists Supplies, name left and count right", _test_equipment_lists_supplies],
		["Equipment says when no Supplies are carried", _test_equipment_with_none],
		["The readout shows the ready Supply and how many", _test_readout_shows_count],
		["The readout hides when no Supplies are carried", _test_readout_hides_with_none],
		["Every Room puts the readout under the Health bar", _test_room_has_readout],
	]


func _test_equipment_lists_supplies() -> bool:
	var player := _player(3)
	var menu := _equipment_menu()
	var body := menu.get_node(MENU_ROOT + "ContentRoot/EquipmentPanel/Body") as GridContainer
	var valid := body != null and body.columns == 2 and _rows(body) == [["Brinecap", "3"]]
	if valid:
		valid = (body.get_child(0) as Label).horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT
		var count := body.get_child(1) as Label
		valid = valid and count.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT
		valid = valid and count.size_flags_horizontal & Control.SIZE_EXPAND != 0
	_close(menu, player)
	return valid


func _test_equipment_with_none() -> bool:
	var player := _player(0)
	var menu := _equipment_menu()
	var body := menu.get_node(MENU_ROOT + "ContentRoot/EquipmentPanel/Body") as Container
	var labels := body.get_children() if body != null else []
	var valid := labels.size() == 1 and (labels[0] as Label).text == "No Supplies carried"
	_close(menu, player)
	return valid


func _test_readout_shows_count() -> bool:
	var player := _player(2)
	var readout := _readout()
	if readout == null:
		player.free()
		return false
	readout.call("_process", 0.0)
	var icon := readout.get_node("Icon") as TextureRect
	var count := readout.get_node("Count") as Label
	var valid := readout.visible and count.text == "2"
	valid = valid and icon.texture != null and icon.texture.resource_path == BRINECAP_SPRITE_PATH
	player.get("health").hurt(20, 0.0)
	player.call("use_supply")
	readout.call("_process", 0.0)
	valid = valid and count.text == "1"
	readout.free()
	player.free()
	_root.get_node("RunState").call("start_run")
	return valid


func _test_readout_hides_with_none() -> bool:
	var player := _player(0)
	var readout := _readout()
	if readout == null:
		player.free()
		return false
	readout.call("_process", 0.0)
	var valid := not readout.visible
	readout.free()
	player.free()
	return valid


func _test_room_has_readout() -> bool:
	var room := FIRST_ROOM_SCENE.instantiate()
	room.call("_ready")
	var readout := room.get_node_or_null("CanvasLayer/SupplyCount") as Control
	var bar := room.get_node_or_null("CanvasLayer/HealthBar") as Control
	var valid := readout != null and bar != null
	valid = valid and readout.position.x == bar.position.x
	valid = valid and readout.position.y >= bar.position.y + bar.size.y
	room.free()
	return valid


# A Player carrying the given number of Brinecaps, in a fresh Run.
func _player(brinecaps: int) -> CharacterBody2D:
	var run := _root.get_node("RunState")
	run.call("start_run")
	if brinecaps > 0:
		run.set("player_supplies", {BRINECAP: brinecaps})
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	_root.add_child(player)
	return player


func _equipment_menu() -> Control:
	var menu := PAUSE_MENU_SCENE.instantiate() as Control
	_root.add_child(menu)
	menu.call("toggle_pause")
	(menu.get_node(MENU_ROOT + "MenuButtons/EquipmentButton") as Button).grab_focus()
	return menu


func _readout() -> Control:
	var scene := load(SUPPLY_COUNT_PATH) as PackedScene
	if scene == null:
		return null
	var readout := scene.instantiate() as Control
	_root.add_child(readout)
	return readout


func _close(menu: Control, player: Node) -> void:
	menu.get_tree().paused = false
	menu.free()
	player.free()
	_root.get_node("RunState").call("start_run")


func _rows(body: Container) -> Array:
	var rows := []
	var labels := body.get_children()
	for index in range(0, labels.size() - 1, 2):
		rows.append([(labels[index] as Label).text, (labels[index + 1] as Label).text])
	return rows
