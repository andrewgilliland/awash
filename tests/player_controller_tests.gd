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
		["Controller charges while melee is held", _test_charges_while_melee_held],
		["Controller attacks on melee release", _test_attacks_on_melee_release],
		["Controller locks attack until it finishes", _test_locks_attack_until_finished],
		["Controller ends attack by floor contact", _test_ends_attack_by_floor_contact],
		["Controller keeps charge through a jump", _test_keeps_charge_through_jump],
		["Controller attacks in the air", _test_attacks_in_air],
		["Controller reports each state change once", _test_reports_each_state_change_once],
		["Controller is knocked back by a hit", _test_knocked_back_by_hit],
		["Controller ignores input while stunned", _test_ignores_input_while_stunned],
		["Controller cancels an attack when hit", _test_hit_cancels_attack],
		["Controller reports a jump, not a walk off a ledge", _test_reports_jump],
		["Controller fully charges after holding melee", _test_fully_charges],
		["An Attack after a full Charge is a charged Attack", _test_charged_attack],
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
	var controller := _charged_controller()
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
	var controller := _charged_controller()
	controller.step(_next_frame(controller), DELTA)
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


func _test_charges_while_melee_held() -> bool:
	var controller := PlayerController.new()
	var frame := _next_frame(controller)
	frame.melee_held = true
	controller.step(frame, DELTA)
	var valid := controller.state == PlayerController.State.CHARGE
	valid = valid and not controller.is_moving

	frame = _next_frame(controller)
	frame.melee_held = true
	frame.direction = 1.0
	controller.step(frame, DELTA)
	valid = valid and controller.state == PlayerController.State.CHARGE
	valid = valid and controller.velocity.x > 0.0
	valid = valid and controller.is_moving
	valid = valid and controller.facing == -1.0
	return valid


func _test_attacks_on_melee_release() -> bool:
	var controller := _charged_controller()
	controller.step(_next_frame(controller), DELTA)
	return controller.state == PlayerController.State.ATTACK


func _test_locks_attack_until_finished() -> bool:
	var controller := _charged_controller()
	controller.step(_next_frame(controller), DELTA)

	var frame := _next_frame(controller)
	frame.velocity = Vector2(200.0, 0.0)
	frame.direction = 1.0
	frame.jump_pressed = true
	frame.melee_held = true
	controller.step(frame, DELTA)

	var valid := controller.state == PlayerController.State.ATTACK
	valid = valid and controller.facing == -1.0
	valid = valid and controller.velocity.x == 200.0 - controller.friction * DELTA
	valid = valid and controller.velocity.y == 0.0
	return valid


func _test_ends_attack_by_floor_contact() -> bool:
	var grounded := _charged_controller()
	grounded.step(_next_frame(grounded), DELTA)
	var frame := _next_frame(grounded)
	frame.attack_finished = true
	grounded.step(frame, DELTA)

	var airborne := _charged_controller()
	airborne.step(_next_frame(airborne), DELTA)
	frame = _next_frame(airborne)
	frame.attack_finished = true
	frame.on_floor = false
	airborne.step(frame, DELTA)

	return (
		grounded.state == PlayerController.State.IDLE
		and airborne.state == PlayerController.State.JUMP
	)


func _test_keeps_charge_through_jump() -> bool:
	var controller := _charged_controller()
	var frame := _next_frame(controller)
	frame.melee_held = true
	frame.jump_pressed = true
	controller.step(frame, DELTA)

	return (
		controller.state == PlayerController.State.CHARGE
		and controller.velocity.y == controller.jump_velocity
	)


func _test_attacks_in_air() -> bool:
	var controller := _charged_controller()
	var frame := _next_frame(controller)
	frame.on_floor = false
	frame.velocity = Vector2(200.0, 0.0)
	controller.step(frame, DELTA)
	var valid := controller.state == PlayerController.State.ATTACK

	frame = _next_frame(controller)
	frame.on_floor = false
	frame.direction = 1.0
	controller.step(frame, DELTA)
	valid = valid and controller.velocity.x == 200.0 - 2.0 * controller.friction * DELTA
	return valid


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
	frame = _next_frame(controller)
	frame.melee_held = true
	frame.jump_pressed = true
	controller.step(frame, DELTA)

	return (
		changes
		== [
			[PlayerController.State.IDLE, PlayerController.State.WALK],
			[PlayerController.State.WALK, PlayerController.State.CHARGE],
		]
	)


func _test_fully_charges() -> bool:
	var controller := _charged_controller()
	var valid: bool = not controller.is_fully_charged()
	_hold_melee(controller, controller.charge_time)
	valid = valid and controller.is_fully_charged()
	# A jump mid-charge keeps it full.
	var frame := _next_frame(controller)
	frame.melee_held = true
	frame.jump_pressed = true
	controller.step(frame, DELTA)
	valid = valid and controller.is_fully_charged()
	controller.step(_next_frame(controller), DELTA)
	return valid and not controller.is_fully_charged()


func _test_charged_attack() -> bool:
	# A quick tap swings plainly.
	var controller := _charged_controller()
	controller.step(_next_frame(controller), DELTA)
	var valid := controller.state == PlayerController.State.ATTACK
	valid = valid and not controller.charged_attack

	var frame := _next_frame(controller)
	frame.attack_finished = true
	controller.step(frame, DELTA)
	frame = _next_frame(controller)
	frame.melee_held = true
	controller.step(frame, DELTA)
	_hold_melee(controller, controller.charge_time)
	controller.step(_next_frame(controller), DELTA)
	valid = valid and controller.state == PlayerController.State.ATTACK
	valid = valid and controller.charged_attack

	# The next quick tap is plain again.
	frame = _next_frame(controller)
	frame.attack_finished = true
	controller.step(frame, DELTA)
	frame = _next_frame(controller)
	frame.melee_held = true
	controller.step(frame, DELTA)
	controller.step(_next_frame(controller), DELTA)
	return valid and not controller.charged_attack


# Keeps melee held for at least the given time.
func _hold_melee(controller: PlayerController, time: float) -> void:
	for i in ceili(time / DELTA) + 1:
		var frame := _next_frame(controller)
		frame.melee_held = true
		controller.step(frame, DELTA)


func _charged_controller() -> PlayerController:
	var controller := PlayerController.new()
	var frame := _next_frame(controller)
	frame.melee_held = true
	controller.step(frame, DELTA)
	return controller


func _next_frame(controller: PlayerController) -> PlayerController.Frame:
	var frame := PlayerController.Frame.new()
	frame.velocity = controller.velocity
	return frame
