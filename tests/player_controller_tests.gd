extends RefCounted

const PlayerController := preload("res://scripts/player/player_controller.gd")
const DELTA := 0.1


func get_tests() -> Array:
	return [
		["Controller starts idle facing left", _test_starts_idle_facing_left],
		["Controller walks toward input direction", _test_walks_toward_input_direction],
		["Controller applies friction without input", _test_applies_friction_without_input],
		["Controller jumps from the floor", _test_jumps_from_floor],
		["Controller ignores jump while airborne", _test_ignores_jump_while_airborne],
		["Controller reports each state change once", _test_reports_each_state_change_once],
		["Controller is knocked back by a hit", _test_knocked_back_by_hit],
		["Controller ignores input while stunned", _test_ignores_input_while_stunned],
		["Controller cancels an attack when hit", _test_hit_cancels_attack],
		["Controller reports a jump, not a walk off a ledge", _test_reports_jump],
	]


func _test_reports_jump() -> bool:
	var controller := PlayerController.new()
	var jumps := [0]
	controller.jumped.connect(func() -> void: jumps[0] += 1)

	var frame := _next_frame(controller)
	frame.on_floor = false
	controller.step(frame, DELTA)
	var valid: bool = controller.state == PlayerController.State.JUMP and jumps[0] == 0

	frame = _next_frame(controller)
	frame.jump_pressed = true
	controller.step(frame, DELTA)
	frame = _next_frame(controller)
	frame.jump_pressed = true
	frame.on_floor = false
	controller.step(frame, DELTA)
	return valid and jumps[0] == 1


func _test_knocked_back_by_hit() -> bool:
	var controller := _slashing_controller()
	var frame := _next_frame(controller)
	frame.melee_held = true
	frame.knockback = Vector2(90.0, -120.0)
	controller.step(frame, DELTA)
	var valid := controller.velocity == Vector2(90.0, -120.0)
	return valid and controller.state == PlayerController.State.JUMP


func _test_ignores_input_while_stunned() -> bool:
	var controller := PlayerController.new()
	var frame := _next_frame(controller)
	frame.knockback = Vector2(-90.0, -120.0)
	controller.step(frame, DELTA)

	frame = _next_frame(controller)
	frame.direction = 1.0
	frame.jump_pressed = true
	frame.melee_held = true
	controller.step(frame, DELTA)
	var valid := controller.velocity == Vector2(-90.0, -120.0)
	valid = valid and controller.state == PlayerController.State.JUMP
	valid = valid and controller.facing == -1.0

	# Past the stun, input steers again.
	for i in ceili(controller.stun_time / DELTA) + 1:
		frame = _next_frame(controller)
		frame.direction = 1.0
		controller.step(frame, DELTA)
	return valid and controller.state == PlayerController.State.WALK and controller.facing == 1.0


func _test_hit_cancels_attack() -> bool:
	var controller := _slashing_controller()
	var valid := controller.state == PlayerController.State.ATTACK
	var frame := _next_frame(controller)
	frame.knockback = Vector2(90.0, -120.0)
	controller.step(frame, DELTA)
	return valid and controller.state == PlayerController.State.JUMP


func _test_starts_idle_facing_left() -> bool:
	var controller := PlayerController.new()
	return (
		controller.state == PlayerController.State.IDLE
		and controller.facing == -1.0
		and not controller.is_moving
	)


func _test_walks_toward_input_direction() -> bool:
	var controller := PlayerController.new()
	var frame := _next_frame(controller)
	frame.direction = 1.0
	controller.step(frame, DELTA)

	var valid := controller.state == PlayerController.State.WALK
	valid = valid and controller.facing == 1.0
	valid = valid and controller.is_moving
	valid = valid and controller.velocity.x == controller.acceleration * DELTA

	for i in 10:
		frame = _next_frame(controller)
		frame.direction = 1.0
		controller.step(frame, DELTA)

	valid = valid and controller.velocity.x == controller.move_speed
	return valid


func _test_applies_friction_without_input() -> bool:
	var controller := PlayerController.new()
	var frame := _next_frame(controller)
	frame.velocity = Vector2(200.0, 0.0)
	controller.step(frame, DELTA)

	var valid := controller.state == PlayerController.State.IDLE
	valid = valid and controller.velocity.x == 200.0 - controller.friction * DELTA
	valid = valid and controller.facing == -1.0
	return valid


func _test_jumps_from_floor() -> bool:
	var controller := PlayerController.new()
	var frame := _next_frame(controller)
	frame.jump_pressed = true
	controller.step(frame, DELTA)

	return (
		controller.state == PlayerController.State.JUMP
		and controller.velocity.y == controller.jump_velocity
	)


func _test_ignores_jump_while_airborne() -> bool:
	var controller := PlayerController.new()
	var frame := _next_frame(controller)
	frame.on_floor = false
	frame.jump_pressed = true
	frame.velocity = Vector2(0.0, 50.0)
	controller.step(frame, DELTA)

	return controller.state == PlayerController.State.JUMP and controller.velocity.y == 50.0


func _test_reports_each_state_change_once() -> bool:
	var controller := PlayerController.new()
	var changes: Array = []
	controller.state_changed.connect(
		func(previous: PlayerController.State, next: PlayerController.State) -> void:
			changes.append([previous, next])
	)

	var frame := _next_frame(controller)
	frame.direction = 1.0
	controller.step(frame, DELTA)
	frame = _next_frame(controller)
	frame.direction = 1.0
	controller.step(frame, DELTA)
	# A jump and a melee press on one step: it jumps, then slashes, and reports only the slash.
	frame = _next_frame(controller)
	frame.direction = 1.0
	frame.melee_held = true
	frame.jump_pressed = true
	controller.step(frame, DELTA)

	return (
		changes
		== [
			[PlayerController.State.IDLE, PlayerController.State.WALK],
			[PlayerController.State.WALK, PlayerController.State.ATTACK],
		]
	)


# A controller mid-slash, melee just pressed.
func _slashing_controller() -> PlayerController:
	var controller := PlayerController.new()
	var frame := _next_frame(controller)
	frame.melee_held = true
	controller.step(frame, DELTA)
	return controller


func _next_frame(controller: PlayerController) -> PlayerController.Frame:
	var frame := PlayerController.Frame.new()
	frame.velocity = controller.velocity
	return frame
