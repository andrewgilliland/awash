extends RefCounted

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const PAUSE_MENU_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const MENU_ROOT := "CenterContainer/MenuPanel/MarginContainer/VBoxContainer/"
const PANEL := MENU_ROOT + "ContentRoot/InventoryPanel/"
const BRINECAP := &"brinecap"

# Needs a root that is already in the tree: the Panel finds the Player through its group.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Inventory lists each kind, name left and count right", _test_lists_supplies],
		["Inventory says when no Supplies are carried", _test_says_when_none],
		["Down from the Inventory tab reaches each Supply, then Resume", _test_moves_through_rows],
		["Choosing a Brinecap eats it, with play still paused", _test_choosing_eats],
		["At full Health, choosing one keeps it and says so", _test_full_health_keeps],
		["Eating the last one goes back to the Inventory tab", _test_last_one_returns_focus],
	]


func _test_lists_supplies() -> bool:
	var player := _player(3)
	var menu := _supplies_menu()
	var rows := _rows(menu)
	var valid := rows.size() == 1 and rows[0] is Button
	if valid:
		var row := rows[0] as Button
		var count := row.get_node_or_null("Count") as Label
		valid = row.text == "Brinecap" and row.alignment == HORIZONTAL_ALIGNMENT_LEFT
		valid = valid and count != null and count.text == "3"
		valid = valid and count.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT
	_close(menu, player)
	return valid


func _test_says_when_none() -> bool:
	var player := _player(0)
	var menu := _supplies_menu()
	var rows := _rows(menu)
	var valid := rows.size() == 1 and rows[0] is Label
	valid = valid and (rows[0] as Label).text == "No Supplies carried"
	_close(menu, player)
	return valid


func _test_moves_through_rows() -> bool:
	var player := _player(2)
	var menu := _supplies_menu()
	var tab := menu.get_node(MENU_ROOT + "MenuButtons/InventoryButton") as Button
	var resume := menu.get_node(MENU_ROOT + "ResumeButton") as Button
	var row := _rows(menu)[0] as Control
	_navigate(menu, &"ui_down")
	var valid := row.has_focus() and _panel_shown(menu)
	_navigate(menu, &"ui_down")
	valid = valid and resume.has_focus() and _panel_shown(menu)
	_navigate(menu, &"ui_up")
	valid = valid and row.has_focus()
	_navigate(menu, &"ui_up")
	valid = valid and tab.has_focus()
	_close(menu, player)
	return valid


func _test_choosing_eats() -> bool:
	var player := _player(2)
	var health = player.get("health")
	health.hurt(20, 0.0)
	var menu := _supplies_menu()
	_navigate(menu, &"ui_down")
	_navigate(menu, &"ui_accept")
	var row := _rows(menu)[0] as Button
	var eat := player.get_node("Sounds/Eat") as AudioStreamPlayer
	var valid: bool = health.current == health.maximum - 10
	valid = valid and (row.get_node("Count") as Label).text == "1" and row.has_focus()
	valid = valid and menu.get_tree().paused and _panel_shown(menu)
	# The tree is paused, so the eat sound has to play through it.
	valid = valid and eat.process_mode == Node.PROCESS_MODE_ALWAYS and eat.playing
	_close(menu, player)
	return valid


func _test_full_health_keeps() -> bool:
	var player := _player(2)
	var menu := _supplies_menu()
	var note := menu.get_node(PANEL + "Note") as Label
	var valid := not note.visible
	_navigate(menu, &"ui_down")
	_navigate(menu, &"ui_accept")
	var row := _rows(menu)[0] as Button
	valid = valid and (row.get_node("Count") as Label).text == "2"
	valid = valid and note.visible and note.text == "Health is full"
	_close(menu, player)
	return valid


func _test_last_one_returns_focus() -> bool:
	var player := _player(1)
	player.get("health").hurt(20, 0.0)
	var menu := _supplies_menu()
	_navigate(menu, &"ui_down")
	_navigate(menu, &"ui_accept")
	var rows := _rows(menu)
	var tab := menu.get_node(MENU_ROOT + "MenuButtons/InventoryButton") as Button
	var valid := rows.size() == 1 and rows[0] is Label and tab.has_focus()
	valid = valid and _panel_shown(menu)
	_close(menu, player)
	return valid


func _player(brinecaps: int) -> CharacterBody2D:
	var run := _root.get_node("RunState")
	run.call("start_run")
	if brinecaps > 0:
		run.set("player_supplies", {BRINECAP: brinecaps})
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	_root.add_child(player)
	return player


# The Pause menu, paused and moved on to the Inventory.
func _supplies_menu() -> Control:
	var menu := PAUSE_MENU_SCENE.instantiate() as Control
	_root.add_child(menu)
	menu.call("toggle_pause")
	_navigate(menu, &"ui_right")
	return menu


func _rows(menu: Control) -> Array:
	return menu.get_node(PANEL + "Body").get_children()


func _panel_shown(menu: Control) -> bool:
	return (menu.get_node(MENU_ROOT + "ContentRoot/InventoryPanel") as Control).visible


func _navigate(menu: Control, action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		menu.get_viewport().push_input(event)


func _close(menu: Control, player: Node) -> void:
	menu.get_tree().paused = false
	menu.free()
	player.free()
	_root.get_node("RunState").call("start_run")
