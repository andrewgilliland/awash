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
# The tallest the framed bar may be, in pixels.
const SLIM_HEIGHT := 7.0

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
		["Health bar is slim: a thin fill inside its frame", _test_slim],
		["Every Room puts the Health bar under its Pause menu", _test_room_has_bar],
		["Stats shows Health left out of its total", _test_stats_shows_health],
		["Stats shows Level, Experience, Strength and Defense", _test_stats_shows_growth],
		["Stats lines up names on the left, values on the right", _test_stats_columns],
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


func _test_slim() -> bool:
	var bar := _bar()
	var outer := bar.get_combined_minimum_size()
	var valid := outer.y <= SLIM_HEIGHT and HealthBar.FILL_SIZE.y >= 2.0
	# The scene's rect matches what the bar draws.
	valid = valid and bar.size == outer
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
	var body := menu.get_node(MENU_ROOT + "ContentRoot/StatsPanel/Body") as Container
	var valid := _stats_rows(body).has(["Health", "50 / 50"])
	player.get("health").hurt(2 * ONE_HIT, 0.0)
	_reshow_stats(menu)
	valid = valid and _stats_rows(body).has(["Health", "30 / 50"])
	menu.get_tree().paused = false
	menu.free()
	player.free()
	return valid


func _test_stats_shows_growth() -> bool:
	var player := _player()
	var menu := PAUSE_MENU_SCENE.instantiate() as Control
	_root.add_child(menu)
	menu.call("toggle_pause")
	var body := menu.get_node(MENU_ROOT + "ContentRoot/StatsPanel/Body") as Container
	var valid := (
		_stats_rows(body)
		== [
			["Level", "1"],
			["Experience", "0 / 40"],
			["Health", "50 / 50"],
			["Strength", "0"],
			["Defense", "0"],
		]
	)
	player.call("gain_experience", 45)
	_reshow_stats(menu)
	valid = (
		valid
		and (
			_stats_rows(body)
			== [
				["Level", "2"],
				["Experience", "45 / 100"],
				["Health", "60 / 60"],
				["Strength", "0"],
				["Defense", "0"],
			]
		)
	)
	player.call("gain_experience", 1000)
	_reshow_stats(menu)
	valid = (
		valid
		and (
			_stats_rows(body)
			== [
				["Level", "5"],
				["Experience", "1045 / MAX"],
				["Health", "90 / 90"],
				["Strength", "10"],
				["Defense", "0"],
			]
		)
	)
	menu.get_tree().paused = false
	menu.free()
	player.free()
	_root.get_node("RunState").call("start_run")
	return valid


# Each row is a name pinned left and its value pushed out to the Panel's right edge.
func _test_stats_columns() -> bool:
	var player := _player()
	var menu := PAUSE_MENU_SCENE.instantiate() as Control
	_root.add_child(menu)
	menu.call("toggle_pause")
	var body := menu.get_node(MENU_ROOT + "ContentRoot/StatsPanel/Body") as GridContainer
	var valid := body != null and body.columns == 2 and body.get_child_count() == 10
	if valid:
		for index in body.get_child_count():
			var label := body.get_child(index) as Label
			if index % 2 == 0:
				valid = valid and label.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT
			else:
				valid = valid and label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT
				valid = valid and label.size_flags_horizontal & Control.SIZE_EXPAND != 0
	menu.get_tree().paused = false
	menu.free()
	player.free()
	return valid


# Moves to the next Panel and back, so Stats reads the Player afresh.
func _reshow_stats(menu: Control) -> void:
	(menu.get_node(MENU_ROOT + "MenuButtons/EquipmentButton") as Button).grab_focus()
	(menu.get_node(MENU_ROOT + "MenuButtons/StatsButton") as Button).grab_focus()


# The Stats rows as [name, value] pairs, read from the Body's labels in order.
func _stats_rows(body: Container) -> Array:
	var rows := []
	var labels := body.get_children()
	for index in range(0, labels.size() - 1, 2):
		rows.append([(labels[index] as Label).text, (labels[index + 1] as Label).text])
	return rows


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
