extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"

var _failures: int = 0


func _init() -> void:
	_run_playtest("Main scene spawn stays deterministic", _playtest_main_scene_spawn)

	if _failures > 0:
		push_error("%d playtest(s) failed" % _failures)
		quit(1)
		return

	print("All playtests passed")
	quit(0)


func _run_playtest(name: String, playtest_callable: Callable) -> void:
	var result = playtest_callable.call()
	if result:
		print("PASS: %s" % name)
	else:
		_failures += 1
		push_error("FAIL: %s" % name)


func _playtest_main_scene_spawn() -> bool:
	var packed_scene := load(MAIN_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var main_scene := packed_scene.instantiate() as Node2D
	if main_scene == null:
		return false

	main_scene.call("_ready")
	var player := main_scene.get_node_or_null("Player") as CharacterBody2D
	var world_layer := _find_world_tile_layer(main_scene)
	var is_valid := player != null and world_layer != null

	if is_valid:
		is_valid = is_valid and player.global_position != Vector2.ZERO
		is_valid = is_valid and world_layer.tile_set != null
		is_valid = is_valid and world_layer.get_used_cells().size() > 0

	main_scene.free()
	return is_valid


func _find_world_tile_layer(node: Node) -> TileMapLayer:
	for child in node.get_children():
		if child is TileMapLayer:
			return child as TileMapLayer

	return null
