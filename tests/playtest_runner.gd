extends SceneTree

const BIOME_SCENE_PATH := "res://scenes/world/world_biome_01.tscn"

var _failures: int = 0


func _init() -> void:
	_run_playtest("Biome room traversal contract is deterministic", _playtest_biome_room_traversal)

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


func _playtest_biome_room_traversal() -> bool:
	var packed_scene := load(BIOME_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return false

	var biome := packed_scene.instantiate() as Node2D
	if biome == null:
		return false

	biome.call("_ready")

	var room_count := int(biome.call("get_room_count"))
	if room_count < 2:
		biome.free()
		return false

	var traversed_forward_ok := true
	var traversed_backward_ok := true
	var spawn_contract_ok := true

	for i in range(room_count - 1):
		var current_room := StringName("room_%d" % (i + 1))
		var next_room := StringName("room_%d" % (i + 2))
		var adjacent := biome.call("get_adjacent_room_id", current_room, 1) as StringName
		if adjacent != next_room:
			traversed_forward_ok = false
			break

		var bounds := biome.call("get_room_bounds", next_room) as Rect2
		var spawn_left := biome.call("get_room_spawn_position", next_room, &"left") as Vector2
		var spawn_center := biome.call("get_room_spawn_position", next_room, &"center") as Vector2
		var spawn_right := biome.call("get_room_spawn_position", next_room, &"right") as Vector2

		spawn_contract_ok = spawn_contract_ok and spawn_left.x > bounds.position.x
		spawn_contract_ok = spawn_contract_ok and spawn_left.x < bounds.end.x
		spawn_contract_ok = spawn_contract_ok and spawn_center.x > spawn_left.x
		spawn_contract_ok = spawn_contract_ok and spawn_center.x < spawn_right.x
		spawn_contract_ok = spawn_contract_ok and spawn_right.x < bounds.end.x
		spawn_contract_ok = spawn_contract_ok and is_equal_approx(spawn_left.y, spawn_center.y)
		spawn_contract_ok = spawn_contract_ok and is_equal_approx(spawn_center.y, spawn_right.y)

	for i in range(room_count - 1, 0, -1):
		var current_room := StringName("room_%d" % (i + 1))
		var previous_room := StringName("room_%d" % i)
		var adjacent := biome.call("get_adjacent_room_id", current_room, -1) as StringName
		if adjacent != previous_room:
			traversed_backward_ok = false
			break

	var no_left_underflow: bool = (
		biome.call("get_adjacent_room_id", &"room_1", -1) == StringName("")
	)
	var no_right_overflow: bool = (
		biome.call("get_adjacent_room_id", StringName("room_%d" % room_count), 1) == StringName("")
	)

	biome.free()
	return (
		traversed_forward_ok
		and traversed_backward_ok
		and spawn_contract_ok
		and no_left_underflow
		and no_right_overflow
	)
