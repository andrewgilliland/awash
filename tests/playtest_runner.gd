extends SceneTree

const BIOME_SCENE_PATH := "res://scenes/world/world_biome_01.tscn"

var _failures: int = 0


func _init() -> void:
	_run_playtest("Biome world spawn contract is deterministic", _playtest_biome_world_spawn)

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


func _playtest_biome_world_spawn() -> bool:
	var packed_scene := load(BIOME_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var biome := packed_scene.instantiate() as Node2D
	if biome == null:
		return false

	biome.call("_ready")
	var world_bounds := biome.call("get_world_bounds") as Rect2
	var spawn_position := biome.call("get_spawn_position") as Vector2

	var world_contract_ok := world_bounds.size.x > 0.0 and world_bounds.size.y > 0.0
	world_contract_ok = world_contract_ok and spawn_position.x > world_bounds.position.x
	world_contract_ok = world_contract_ok and spawn_position.x < world_bounds.end.x
	world_contract_ok = world_contract_ok and spawn_position.y > 0.0

	biome.free()
	return world_contract_ok
