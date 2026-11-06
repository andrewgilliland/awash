extends RefCounted

# The Supply Shop's panel, opened by talking to Tidefen's TRADER: it pauses play and lists the
# stock, each with how many the Player carries and its price, and the Player's Gold. Choosing a
# row buys one, a row the Player cannot buy is greyed and says why, and Back or cancel closes it.

const PANEL_PATH := "res://scenes/ui/shop_panel.tscn"
const TRADER_PATH := "res://scenes/npcs/trader.tscn"
const TRADER_SHEET := "res://assets/npcs/trader/trader.png"
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const TIDEFEN_SCENE := preload("res://scenes/rooms/tidefen_village_1.tscn")
const FIRST_ROOM_SCENE := preload("res://scenes/rooms/waking_coast_1.tscn")
const Supplies := preload("res://scripts/items/supplies.gd")
# The market stall's columns, and the square's sand.
const STALL_WEST := 568.0
const STALL_EAST := 632.0
const SAND_Y := 112.0
const GREYED := 0.5

# Needs a root that is already in the tree: the panel finds the Player through its group.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Opening the Shop pauses play and lists its stock, prices and Gold", _test_lists],
		["Choosing a row buys one, and the Gold and counts update", _test_buys],
		["A row the Player can't buy is greyed and says why", _test_cannot_buy],
		["Back, or cancel, closes the Shop and play goes on", _test_closes],
		["Talking to the TRADER opens the Shop", _test_trader_opens],
		["Tidefen's TRADER stands at the market stall", _test_trader_in_tidefen],
		["Every Room keeps the Shop panel above its Pause menu", _test_room_has_panel],
	]


func _test_lists() -> bool:
	var player := _player(20)
	player.get("supplies").add(Supplies.BRINECAP)
	var panel := _panel()
	if panel == null:
		player.free()
		return false
	panel.call("open")
	var rows := _rows(panel)
	var valid: bool = panel.call("is_open") and panel.visible and _root.get_tree().paused
	valid = valid and rows.size() == 2 and _gold_text(panel) == "20"
	if valid:
		valid = rows[0].text == "Meat Pie" and _detail(rows[0]) == "x0  15G"
		valid = valid and rows[1].text == "Brinecap" and _detail(rows[1]) == "x1  8G"
		valid = valid and rows[0].has_focus()
	_close(panel, player)
	return valid


func _test_buys() -> bool:
	var player := _player(20)
	var panel := _panel()
	if panel == null:
		player.free()
		return false
	panel.call("open")
	var rows := _rows(panel)
	rows[0].emit_signal(&"pressed")
	var valid: bool = player.get("gold") == 5 and _gold_text(panel) == "5"
	valid = valid and _detail(rows[0]) == "x1  15G"
	valid = valid and player.get("supplies").count(Supplies.MEAT_PIE) == 1
	valid = valid and is_equal_approx(rows[0].modulate.a, GREYED)
	valid = valid and is_equal_approx(rows[1].modulate.a, GREYED)
	_close(panel, player)
	return valid


func _test_cannot_buy() -> bool:
	var player := _player(5)
	var panel := _panel()
	if panel == null:
		player.free()
		return false
	panel.call("open")
	var rows := _rows(panel)
	rows[1].emit_signal(&"pressed")
	var description := panel.get_node("%Description") as Label
	var valid: bool = player.get("gold") == 5 and description.text == "Not enough Gold"
	panel.call("close")
	player.call("gain_gold", 100)
	for i in Supplies.CARRY_LIMIT:
		player.get("supplies").add(Supplies.BRINECAP)
	panel.call("open")
	rows = _rows(panel)
	rows[1].emit_signal(&"pressed")
	valid = valid and description.text == "Can't carry more" and player.get("gold") == 105
	valid = valid and is_equal_approx(rows[1].modulate.a, GREYED)
	valid = valid and is_equal_approx(rows[0].modulate.a, 1.0)
	_close(panel, player)
	return valid


func _test_closes() -> bool:
	var player := _player(0)
	var panel := _panel()
	if panel == null:
		player.free()
		return false
	panel.call("open")
	(panel.get_node("%Back") as Button).emit_signal(&"pressed")
	var valid: bool = not panel.call("is_open") and not _root.get_tree().paused
	panel.call("open")
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	panel.call("_unhandled_input", cancel)
	valid = valid and not panel.call("is_open") and not panel.visible
	valid = valid and not _root.get_tree().paused
	_close(panel, player)
	return valid


func _test_trader_opens() -> bool:
	var player := _player(0)
	var panel := _panel()
	if panel == null or not ResourceLoader.exists(TRADER_PATH):
		player.free()
		if panel != null:
			panel.free()
		return false
	var trader := (load(TRADER_PATH) as PackedScene).instantiate() as Node2D
	trader.position = Vector2(100, 100)
	_root.add_child(trader)
	(player as Node2D).global_position = Vector2(120, 100)
	trader.get_node("Interactable").call("use", player)
	var valid: bool = panel.call("is_open")
	valid = valid and (trader.get_node("AnimatedSprite2D") as AnimatedSprite2D).flip_h
	trader.free()
	_close(panel, player)
	return valid


func _test_trader_in_tidefen() -> bool:
	var room := TIDEFEN_SCENE.instantiate()
	var trader := room.get_node_or_null("Trader") as Node2D
	var valid := trader != null and trader.scene_file_path == TRADER_PATH
	if valid:
		valid = trader.position.x >= STALL_WEST and trader.position.x <= STALL_EAST
		valid = valid and is_equal_approx(trader.position.y, SAND_Y)
		valid = valid and trader.get("speaker") == "TRADER"
		var sheet := trader.get("sheet") as Texture2D
		valid = valid and sheet != null and sheet.resource_path == TRADER_SHEET
		valid = valid and sheet.get_size() == Vector2(32, 16)
	room.free()
	return valid


func _test_room_has_panel() -> bool:
	var room := FIRST_ROOM_SCENE.instantiate()
	_root.add_child(room)
	var canvas := room.get_node("CanvasLayer")
	var panel := canvas.get_node_or_null("ShopPanel")
	var menu := canvas.get_node_or_null("PauseMenu")
	var valid := panel != null and menu != null and panel.get_index() > menu.get_index()
	valid = valid and not panel.visible
	room.free()
	_root.get_tree().paused = false
	_root.get_node("RunState").call("start_run")
	return valid


func _player(gold: int) -> Node:
	_root.get_node("RunState").call("start_run")
	var player := PLAYER_SCENE.instantiate()
	_root.add_child(player)
	player.call("gain_gold", gold)
	return player


func _panel() -> Control:
	if not ResourceLoader.exists(PANEL_PATH):
		return null
	var panel := (load(PANEL_PATH) as PackedScene).instantiate() as Control
	_root.add_child(panel)
	return panel


func _rows(panel: Control) -> Array[Button]:
	var rows: Array[Button] = []
	for row in panel.get_node("%Rows").get_children():
		if row is Button:
			rows.append(row)
	return rows


static func _detail(row: Button) -> String:
	var label := row.get_node_or_null("Detail") as Label
	return label.text if label != null else ""


static func _gold_text(panel: Control) -> String:
	return (panel.get_node("%Gold") as Label).text


func _close(panel: Node, player: Node) -> void:
	panel.free()
	player.free()
	_root.get_tree().paused = false
	_root.get_node("RunState").call("start_run")
