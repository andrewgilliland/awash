extends RefCounted

const PlayerController := preload("res://scripts/player/player_controller.gd")
const DELTA := 0.1
# One physics frame, for the jump's short windows.
const FRAME := 1.0 / 60.0


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
		["Controller still jumps just after walking off a ledge", _test_coyote_jump],
		["Controller won't jump long after walking off a ledge", _test_coyote_runs_out],
		["Controller's grace off a ledge never follows a jump", _test_no_coyote_after_jump],
		["Controller's grace off a ledge never follows a hit", _test_no_coyote_after_hit],
		["Controller jumps on landing when jump was pressed just before", _test_buffered_landing],
		["Controller forgets a jump pressed long before landing", _test_buffer_runs_out],
		["Controller jumps as an Attack ends when pressed near its end", _test_buffered_attack],
		["Letting go of jump while rising halves the rise, once", _test_jump_cut],
		["Holding jump keeps the whole rise", _test_jump_held],
		["Letting go of jump once falling changes nothing", _test_no_cut_falling],
		["Letting go of jump leaves a hit's rise alone", _test_no_cut_knockback],
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


# Standing, then walking off a ledge for some frames, then pressing jump in the air.
func _test_coyote_jump() -> bool:
	var controller := _off_ledge(4)
	_press_jump_in_air(controller)
	return controller.velocity.y == controller.jump_velocity


func _test_coyote_runs_out() -> bool:
	var controller := _off_ledge(8)
	_press_jump_in_air(controller)
	return controller.velocity.y != controller.jump_velocity


func _test_no_coyote_after_jump() -> bool:
	var controller := PlayerController.new()
	var jumps := [0]
	controller.jumped.connect(func() -> void: jumps[0] += 1)
	var frame := _next_frame(controller)
	frame.jump_pressed = true
	frame.jump_held = true
	controller.step(frame, FRAME)
	for i in 2:
		frame = _next_frame(controller)
		frame.on_floor = false
		controller.step(frame, FRAME)
	_press_jump_in_air(controller)
	return jumps[0] == 1


func _test_no_coyote_after_hit() -> bool:
	var controller := PlayerController.new()
	var frame := _next_frame(controller)
	frame.knockback = Vector2(90.0, -120.0)
	controller.step(frame, FRAME)
	while controller.state == PlayerController.State.JUMP and controller.time_in_state < 0.31:
		frame = _next_frame(controller)
		frame.on_floor = false
		controller.step(frame, FRAME)
	_press_jump_in_air(controller)
	return controller.velocity.y != controller.jump_velocity


func _test_buffered_landing() -> bool:
	return _landing_after_press(4).velocity.y == PlayerController.new().jump_velocity


func _test_buffer_runs_out() -> bool:
	return _landing_after_press(9).velocity.y != PlayerController.new().jump_velocity


func _test_buffered_attack() -> bool:
	var controller := _slashing_controller()
	var frame := _next_frame(controller)
	frame.jump_pressed = true
	frame.jump_held = true
	controller.step(frame, FRAME)
	var valid := controller.state == PlayerController.State.ATTACK
	valid = valid and controller.velocity.y != controller.jump_velocity
	for i in 3:
		frame = _next_frame(controller)
		frame.jump_held = true
		controller.step(frame, FRAME)
	frame = _next_frame(controller)
	frame.jump_held = true
	frame.attack_finished = true
	controller.step(frame, FRAME)
	return valid and controller.velocity.y == controller.jump_velocity


func _test_jump_cut() -> bool:
	var controller := _jumped()
	_rise(controller, -200.0, false)
	var valid := is_equal_approx(controller.velocity.y, -100.0)
	_rise(controller, -90.0, false)
	return valid and is_equal_approx(controller.velocity.y, -90.0)


func _test_jump_held() -> bool:
	var controller := _jumped()
	_rise(controller, -200.0, true)
	return is_equal_approx(controller.velocity.y, -200.0)


func _test_no_cut_falling() -> bool:
	var controller := _jumped()
	_rise(controller, 30.0, true)
	_rise(controller, 40.0, false)
	return is_equal_approx(controller.velocity.y, 40.0)


func _test_no_cut_knockback() -> bool:
	var controller := PlayerController.new()
	var frame := _next_frame(controller)
	frame.knockback = Vector2(90.0, -120.0)
	controller.step(frame, FRAME)
	for i in 20:
		_rise(controller, -100.0, false)
	return is_equal_approx(controller.velocity.y, -100.0)


func _jumped() -> PlayerController:
	var controller := PlayerController.new()
	var frame := _next_frame(controller)
	frame.jump_pressed = true
	frame.jump_held = true
	controller.step(frame, FRAME)
	return controller


# One airborne frame at the given upward or downward speed, jump held or not.
func _rise(controller: PlayerController, speed: float, held: bool) -> void:
	var frame := _next_frame(controller)
	frame.on_floor = false
	frame.velocity.y = speed
	frame.jump_held = held
	controller.step(frame, FRAME)


# Falling, jump is pressed, and the Player lands that many frames later, still holding it.
func _landing_after_press(frames: int) -> PlayerController:
	var controller := PlayerController.new()
	var frame := _next_frame(controller)
	frame.on_floor = false
	frame.velocity.y = 60.0
	controller.step(frame, FRAME)
	_press_jump_in_air(controller)
	for i in frames - 1:
		frame = _next_frame(controller)
		frame.on_floor = false
		frame.jump_held = true
		controller.step(frame, FRAME)
	frame = _next_frame(controller)
	frame.jump_held = true
	controller.step(frame, FRAME)
	return controller


func _off_ledge(frames: int) -> PlayerController:
	var controller := PlayerController.new()
	controller.step(_next_frame(controller), FRAME)
	for i in frames:
		var frame := _next_frame(controller)
		frame.on_floor = false
		frame.velocity.y = 20.0
		controller.step(frame, FRAME)
	return controller


func _press_jump_in_air(controller: PlayerController) -> void:
	var frame := _next_frame(controller)
	frame.on_floor = false
	frame.jump_pressed = true
	frame.jump_held = true
	controller.step(frame, FRAME)


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
