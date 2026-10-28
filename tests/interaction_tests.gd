extends RefCounted

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const MARA_SCENE := preload("res://scenes/npcs/mara.tscn")
const Interactable := preload("res://scripts/world/interactable.gd")
const TRIGGER_LAYER := 1 << 7
const PLAYER_LAYER := 1 << 1

# Needs a root that is already in the tree: the Player finds Interactables through their group.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["Interactable sits on the trigger layer, watching the Player", _test_layers],
		["Interact uses the nearest Interactable in range", _test_uses_nearest],
		["Interact does nothing out of range", _test_out_of_range],
		["Interact does nothing while the Player is held still", _test_locked],
		["The prompt shows only while the Player can interact", _test_prompt],
		["Mara is reached through an Interactable", _test_mara_interactable],
	]


func _test_layers() -> bool:
	var target := Interactable.new()
	var valid := target.collision_layer == TRIGGER_LAYER and target.collision_mask == PLAYER_LAYER
	valid = valid and not target.monitorable and target.is_in_group(&"interactable")
	target.free()
	return valid


func _test_uses_nearest() -> bool:
	var player := _player(Vector2(100, 100))
	var near := _interactable(Vector2(110, 100))
	var far := _interactable(Vector2(130, 100))
	for target in [near, far]:
		target.call("_on_body_entered", player)
	var used := []
	near.interacted.connect(func(_by: Node) -> void: used.append("near"))
	far.interacted.connect(func(_by: Node) -> void: used.append("far"))
	var interacted_with: Variant = player.call("interact")
	var valid: bool = used == ["near"] and interacted_with == near
	for node in [player, near, far]:
		node.free()
	return valid


func _test_out_of_range() -> bool:
	var player := _player(Vector2(100, 100))
	var target := _interactable(Vector2(110, 100))
	var used := [false]
	target.interacted.connect(func(_by: Node) -> void: used[0] = true)
	var interacted_with: Variant = player.call("interact")
	var valid: bool = not used[0] and interacted_with == null
	player.free()
	target.free()
	return valid


func _test_locked() -> bool:
	var player := _player(Vector2(100, 100))
	var target := _interactable(Vector2(110, 100))
	target.call("_on_body_entered", player)
	player.set("controls_locked", true)
	var used := [false]
	target.interacted.connect(func(_by: Node) -> void: used[0] = true)
	player.call("interact")
	var valid: bool = not used[0]
	player.free()
	target.free()
	return valid


func _test_prompt() -> bool:
	var player := _player(Vector2(100, 100))
	var target := _interactable(Vector2(110, 100))
	var prompt := target.get_node("Prompt") as CanvasItem
	target.call("_process", 0.0)
	var valid := not prompt.visible
	target.call("_on_body_entered", player)
	target.call("_process", 0.0)
	valid = valid and prompt.visible
	player.set("controls_locked", true)
	target.call("_process", 0.0)
	valid = valid and not prompt.visible
	player.set("controls_locked", false)
	target.call("_on_body_exited", player)
	target.call("_process", 0.0)
	valid = valid and not prompt.visible
	player.free()
	target.free()
	return valid


func _test_mara_interactable() -> bool:
	var mara := MARA_SCENE.instantiate()
	var target := mara.get_node_or_null("Interactable") as Area2D
	var valid := target is Interactable and mara.get_node_or_null("TalkZone") == null
	mara.free()
	return valid


func _player(at: Vector2) -> CharacterBody2D:
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	player.position = at
	_root.add_child(player)
	return player


func _interactable(at: Vector2) -> Interactable:
	var target := Interactable.new()
	target.position = at
	_root.add_child(target)
	return target
