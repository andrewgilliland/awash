extends RefCounted

const START_SCREEN := preload("res://scenes/ui/start_screen.tscn")
const TILESET_PATH := "res://assets/tilesets/waking_coast_2.tres"
# A near palm's crown middle and base on each edge, standing on the beach row.
const PALMS := {
	Vector2i(0, 2): Vector2i(1, 10),
	Vector2i(0, 7): Vector2i(3, 10),
	Vector2i(9, 2): Vector2i(1, 10),
	Vector2i(9, 7): Vector2i(3, 10),
}
const BEACH_ROW := 8
const SCREEN_COLUMNS := 10

# Needs a root that is already in the tree: focus and sounds only work inside it.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Start screen shows the logo and a blinking prompt", _test_shows_logo_and_prompt],
		["A start press opens the menu on START", _test_start_press_opens_menu],
		["Moving between menu options ticks", _test_moving_ticks],
		["Start screen frames the beach with palms", _test_palms_frame_beach],
		["Start screen plays its theme on a loop", _test_plays_looping_theme],
	]


func _test_shows_logo_and_prompt() -> bool:
	var screen := _screen()
	var logo := screen.get_node_or_null("Logo") as AnimatedSprite2D
	var valid := logo != null and logo.sprite_frames.get_frame_count(&"default") == 4
	valid = valid and logo.autoplay == "default"
	valid = valid and screen.get_node_or_null("Backdrop") is AnimatedSprite2D
	valid = valid and _prompt(screen).visible and not _menu(screen).visible
	screen.free()
	return valid


func _test_start_press_opens_menu() -> bool:
	var screen := _screen()
	screen.call("_unhandled_input", _action(&"ui_accept"))
	var valid := _menu(screen).visible and not _prompt(screen).visible
	valid = valid and _button(screen, "Start").has_focus()
	screen.free()
	return valid


func _test_moving_ticks() -> bool:
	var screen := _screen()
	screen.call("_unhandled_input", _action(&"ui_accept"))
	var tick := screen.get_node("Sounds/Move") as AudioStreamPlayer
	tick.stop()
	_button(screen, "Quit").grab_focus()
	var valid := tick.playing and tick.bus == &"SFX"
	screen.free()
	return valid


func _test_palms_frame_beach() -> bool:
	var screen := _screen()
	var trees := screen.get_node_or_null("Trees") as TileMapLayer
	var beach := screen.get_node_or_null("Beach") as TileMapLayer
	var valid := trees != null and beach != null
	if valid:
		valid = trees.tile_set.resource_path == TILESET_PATH
		for cell in PALMS:
			valid = valid and trees.get_cell_atlas_coords(cell) == PALMS[cell]
		for column in range(SCREEN_COLUMNS):
			valid = valid and beach.get_cell_source_id(Vector2i(column, BEACH_ROW)) == 0
	screen.free()
	return valid


func _test_plays_looping_theme() -> bool:
	var screen := _screen()
	var music := screen.get_node_or_null("Music") as AudioStreamPlayer
	# The theme starts a moment after the screen appears.
	var waiting := music != null and not music.playing
	screen.call("_start_music")
	var valid := music != null and AudioServer.get_bus_index(&"Music") != -1
	if valid:
		var theme := music.stream as AudioStreamWAV
		valid = theme != null and theme.loop_mode == AudioStreamWAV.LOOP_FORWARD
		valid = valid and music.bus == &"Music" and music.playing and waiting
	screen.free()
	return valid


func _screen() -> Node:
	var screen := START_SCREEN.instantiate()
	_root.add_child(screen)
	return screen


func _prompt(screen: Node) -> Label:
	return screen.get_node("UI/PressStart") as Label


func _menu(screen: Node) -> Control:
	return screen.get_node("UI/Menu") as Control


func _button(screen: Node, name: String) -> Button:
	return screen.get_node("UI/Menu/%sButton" % name) as Button


func _action(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event
