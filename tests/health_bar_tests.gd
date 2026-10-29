extends RefCounted

const HEALTH_BAR_SCENE := preload("res://scenes/ui/health_bar.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const PAUSE_MENU_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const FIRST_ROOM_SCENE := preload("res://scenes/rooms/waking_coast_1.tscn")
const HealthBar := preload("res://scripts/ui/health_bar.gd")
const SCREEN_SIZE := Vector2(160, 144)
const MENU_ROOT := "CenterContainer/MenuPanel/MarginContainer/VBoxContainer/"
const FRAME := 1.0 / 60.0
const ONE_HIT := 10

# Needs a root that is already in the tree: the bar and Stats find the Player through its group.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Health bar fills to the share of Health left", _test_fills_to_share],
		["A hit drops the fill, and the lost Health drains away after it", _test_hit_drains],
		["Health bar hides with no Player", _test_hides_without_player],
		["Health bar sits in the top-left corner, on screen", _test_top_left],
		["Every Room puts the Health bar under its Pause menu", _test_room_has_bar],
		["Stats shows Health left out of its total", _test_stats_shows_health],
		["A defeated Player stops answering controls", _test_defeat_locks_controls],
	]


func _test_fills_to_share() -> bool:
	var player := _player()
	var bar := _bar()
	# Before it has read the Player's Health it shows neither fill nor trail.
	var valid: bool = bar.call("fill_fraction") == 0.0 and bar.call("trail_fraction") == 0.0
	bar.call("_process", FRAME)
	valid = valid and is_equal_approx(bar.call("fill_fraction"), 1.0)
	valid = valid and is_equal_approx(bar.call("trail_fraction"), 1.0)
	player.get("health").hurt(15, 0.0)
	# Settled long after the hit: no trail left behind the fill.
	for i in int((HealthBar.HOLD_TIME + HealthBar.DRAIN_TIME) / FRAME) + 2:
		bar.call("_process", FRAME)
	valid = valid and is_equal_approx(bar.call("fill_fraction"), 0.7)
	valid = valid and is_equal_approx(bar.call("trail_fraction"), 0.7)
	bar.free()
	player.free()
	return valid


func _test_hit_drains() -> bool:
	var player := _player()
	var bar := _bar()
	bar.call("_process", FRAME)
	player.get("health").hurt(ONE_HIT, 0.0)
	bar.call("_process", FRAME)
	# The fill drops at once; the lost Health stays as a trail, then drains down to it.
	var valid := is_equal_approx(bar.call("fill_fraction"), 0.8)
	valid = valid and is_equal_approx(bar.call("trail_fraction"), 1.0)
	for i in int((HealthBar.HOLD_TIME + HealthBar.DRAIN_TIME / 2.0) / FRAME):
		bar.call("_process", FRAME)
	var midway: float = bar.call("trail_fraction")
	valid = valid and midway < 1.0 and midway > 0.8
	for i in int(HealthBar.DRAIN_TIME / FRAME) + 2:
		bar.call("_process", FRAME)
	valid = valid and is_equal_approx(bar.call("trail_fraction"), 0.8)
	bar.free()
	player.free()
	return valid


func _test_hides_without_player() -> bool:
	var bar := _bar()
	bar.call("_process", FRAME)
	var valid := not bar.visible
	var player := _player()
	bar.call("_process", FRAME)
	valid = valid and bar.visible
	bar.free()
	player.free()
	return valid


func _test_top_left() -> bool:
	var bar := _bar()
	var rect := Rect2(bar.position, bar.get_combined_minimum_size())
	var valid := rect.position.x <= 8.0 and rect.position.y <= 8.0
	valid = valid and rect.end.x <= SCREEN_SIZE.x / 2.0 and rect.end.y <= SCREEN_SIZE.y / 4.0
	bar.free()
	return valid


func _test_room_has_bar() -> bool:
	var room := FIRST_ROOM_SCENE.instantiate()
	_root.add_child(room)
	var canvas := room.get_node("CanvasLayer")
	var bar := canvas.get_node_or_null("HealthBar")
	var menu := canvas.get_node_or_null("PauseMenu")
	var valid := bar is HealthBar and menu != null and bar.get_index() < menu.get_index()
	room.free()
	_root.get_tree().paused = false
	return valid


func _test_stats_shows_health() -> bool:
	var player := _player()
	var menu := PAUSE_MENU_SCENE.instantiate() as Control
	_root.add_child(menu)
	menu.call("toggle_pause")
	var stats_button := menu.get_node(MENU_ROOT + "MenuButtons/StatsButton") as Button
	var body := menu.get_node(MENU_ROOT + "ContentRoot/StatsPanel/Body") as Label
	stats_button.pressed.emit()
	var valid := body.text == "Health 50 / 50"
	player.get("health").hurt(2 * ONE_HIT, 0.0)
	(menu.get_node(MENU_ROOT + "ContentRoot/StatsPanel/BackButton") as Button).pressed.emit()
	stats_button.pressed.emit()
	valid = valid and body.text == "Health 30 / 50"
	menu.get_tree().paused = false
	menu.free()
	player.free()
	return valid


func _test_defeat_locks_controls() -> bool:
	var player := _player()
	player.get("health").hurt(4 * ONE_HIT, 0.0)
	var hitbox := Area2D.new()
	hitbox.position = player.position + Vector2(10, 0)
	_root.add_child(hitbox)
	player.call("_on_hurtbox_hit", hitbox)
	var valid: bool = player.call("is_defeated")
	Input.action_press(&"move_right")
	var frame: Object = player.call("_read_frame")
	Input.action_release(&"move_right")
	valid = valid and frame.get("direction") == 0.0
	hitbox.free()
	player.free()
	return valid


func _bar() -> Control:
	var bar := HEALTH_BAR_SCENE.instantiate() as Control
	_root.add_child(bar)
	return bar


# A Player starting a fresh Run, so no Health carried from another test leaks in.
func _player() -> CharacterBody2D:
	var run := _root.get_node_or_null("RunState")
	if run != null:
		run.call("start_run")
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	player.position = Vector2(100, 100)
	_root.add_child(player)
	return player
