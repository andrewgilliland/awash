extends RefCounted

# A Villager: someone who stands in a Room, idling, and talks when Interact uses them, in their
# own name, turning to face whoever talks to them.

const VILLAGER_PATH := "res://scenes/npcs/villager.tscn"
const DIALOGUE_BOX := preload("res://scenes/ui/dialogue_box.tscn")
const Interactable := preload("res://scripts/world/interactable.gd")
const SHEET_PATH := "res://assets/npcs/mara/mara_venn_1.png"
const SPEAKER := "NETTER"
const LINES := ["The tide's turning.", "Mind the shallows."]

# Needs a root that is already in the tree: a Villager builds its sprite in _ready.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["A Villager is reached through an Interactable", _test_reached],
		["A Villager's lines are spoken in its own name, in order", _test_conversation],
		["Talking to a Villager opens its lines in the Dialogue box", _test_talks],
		["A Villager turns to face whoever talks to it", _test_faces],
		["A Villager idles on the two frames of its sheet", _test_idles],
	]


func _test_reached() -> bool:
	var villager := _villager()
	if villager == null:
		return false
	var valid := villager.get_node_or_null("Interactable") is Interactable
	villager.free()
	return valid


func _test_conversation() -> bool:
	var villager := _villager()
	if villager == null:
		return false
	var expected := [[SPEAKER, LINES[0]], [SPEAKER, LINES[1]]]
	var valid: bool = villager.call("conversation") == expected
	villager.free()
	return valid


func _test_talks() -> bool:
	var villager := _villager()
	if villager == null:
		return false
	var box := DIALOGUE_BOX.instantiate()
	_root.add_child(box)
	var by := Node2D.new()
	_root.add_child(by)
	villager.get_node("Interactable").call("use", by)
	var valid: bool = box.call("is_open")
	valid = valid and (box.get_node("%Speaker") as Label).text == SPEAKER
	box.free()
	by.free()
	villager.free()
	return valid


func _test_faces() -> bool:
	var villager := _villager()
	if villager == null:
		return false
	var sprite := villager.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var by := Node2D.new()
	_root.add_child(by)
	# Its sheet faces left, as Mara's does.
	by.global_position = villager.global_position + Vector2(20, 0)
	villager.get_node("Interactable").call("use", by)
	var valid := sprite.flip_h
	by.global_position = villager.global_position - Vector2(20, 0)
	villager.get_node("Interactable").call("use", by)
	valid = valid and not sprite.flip_h
	by.free()
	villager.free()
	return valid


func _test_idles() -> bool:
	var villager := _villager()
	if villager == null:
		return false
	var sprite := villager.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var frames := sprite.sprite_frames
	var valid := frames != null and sprite.animation == &"idle" and sprite.is_playing()
	if valid:
		valid = frames.get_frame_count(&"idle") == 2 and frames.get_animation_loop(&"idle")
		for index in 2:
			var frame := frames.get_frame_texture(&"idle", index) as AtlasTexture
			valid = valid and frame != null and frame.atlas.resource_path == SHEET_PATH
			valid = valid and frame.region == Rect2(index * 16, 0, 16, 16)
	villager.free()
	return valid


func _villager() -> Node2D:
	if not ResourceLoader.exists(VILLAGER_PATH):
		return null
	var villager := (load(VILLAGER_PATH) as PackedScene).instantiate() as Node2D
	villager.set("speaker", SPEAKER)
	villager.set("lines", PackedStringArray(LINES))
	villager.set("sheet", load(SHEET_PATH))
	villager.position = Vector2(100, 100)
	_root.add_child(villager)
	return villager
