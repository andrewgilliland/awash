extends RefCounted

const DIALOGUE_BOX := preload("res://scenes/ui/dialogue_box.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const MARA_SCENE := preload("res://scenes/npcs/mara.tscn")
const FIRST_ROOM := preload("res://scenes/rooms/waking_coast_1.tscn")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const TRIGGER_LAYER := 1 << 7
const PLAYER_LAYER := 1 << 1
const MARA_SHEET_PATH := "res://assets/sprites/npcs/mara/mara_venn_1.png"
const IntroScript := preload("res://scripts/story/intro.gd")
const MaraScript := preload("res://scripts/npcs/mara.gd")
# The box's text area: 142 pixels of 6-pixel glyphs, three rows deep.
const BOX_COLUMNS := 23
const BOX_ROWS := 3

# Needs a root that is already in the tree: the box finds the Player through its group.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Dialogue box shows a speaker's line and locks the Player", _test_box_shows_and_locks],
		["Dialogue box closes after its last line", _test_box_closes],
		["Mara stands in the first Room with a talk zone", _test_mara_in_first_room],
		["Mara is drawn from her sprite sheet", _test_mara_sprite],
		["A fresh Run is not owed the intro", _test_start_run_clears_intro],
		["Every line fits the dialogue box", _test_lines_fit_box],
	]


func _test_box_shows_and_locks() -> bool:
	var player := PLAYER_SCENE.instantiate()
	_root.add_child(player)
	var box := DIALOGUE_BOX.instantiate()
	_root.add_child(box)
	var valid: bool = not box.visible and not player.get("controls_locked")
	box.call("show_lines", [["MARA", "You're breathing."]])
	valid = valid and box.visible and player.get("controls_locked")
	valid = valid and (box.get_node("%Speaker") as Label).text == "MARA"
	(box.get("dialogue") as Object).call("step", 10.0)
	box.call("_process", 0.0)
	valid = valid and (box.get_node("%Text") as Label).text == "You're breathing."
	box.free()
	player.free()
	return valid


func _test_box_closes() -> bool:
	var box := DIALOGUE_BOX.instantiate()
	_root.add_child(box)
	var closed := [false]
	box.connect(&"closed", func() -> void: closed[0] = true)
	box.call("show_lines", [["MARA", "Go."]])
	box.call("advance")
	box.call("advance")
	var valid: bool = closed[0] and not box.visible
	box.free()
	return valid


func _test_mara_in_first_room() -> bool:
	var room := FIRST_ROOM.instantiate()
	var mara := room.get_node_or_null("Mara") as Node2D
	var valid := mara != null and mara.scene_file_path == MARA_SCENE.resource_path
	if valid:
		var zone := mara.get_node_or_null("TalkZone") as Area2D
		valid = zone != null and zone.collision_layer == TRIGGER_LAYER
		valid = valid and zone.collision_mask == PLAYER_LAYER
		var start := room.get_node("Entries/start") as Marker2D
		valid = valid and mara.position.x > start.position.x
		valid = valid and mara.position.distance_to(start.position) < 40.0
	room.free()
	return valid


func _test_mara_sprite() -> bool:
	var mara := MARA_SCENE.instantiate()
	_root.add_child(mara)
	var sprite := mara.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var frames := sprite.sprite_frames
	var valid := frames != null and frames.has_animation(&"idle") and frames.has_animation(&"walk")
	if valid:
		var texture := frames.get_frame_texture(&"walk", 0) as AtlasTexture
		valid = texture != null and texture.atlas.resource_path == MARA_SHEET_PATH
		valid = valid and frames.get_frame_count(&"walk") == 2
	mara.free()
	return valid


func _test_start_run_clears_intro() -> bool:
	var run := RunStateScript.new()
	var valid := not run.intro_pending
	run.intro_pending = true
	run.start_run()
	valid = valid and not run.intro_pending
	run.free()
	return valid


func _test_lines_fit_box() -> bool:
	var valid := true
	for line in IntroScript.LINES + MaraScript.REMINDER:
		var rows := _wrapped_rows(line[1])
		if rows > BOX_ROWS:
			push_error("Too long for the dialogue box (%d rows): %s" % [rows, line[1]])
			valid = false
	return valid


# Word-wraps text the way the box's label does, counting the rows it fills.
static func _wrapped_rows(text: String) -> int:
	var rows := 1
	var width := 0
	for word in text.split(" "):
		var needed := word.length() if width == 0 else width + 1 + word.length()
		if needed > BOX_COLUMNS:
			rows += 1
			width = word.length()
		else:
			width = needed
	return rows
