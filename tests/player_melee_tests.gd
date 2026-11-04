extends RefCounted

# The Player controller's melee: a press slashes at once, melee held through the slash goes into
# the Charge, and a full Charge let go swings a charged Attack, the one that looses a Sword Beam.

const PlayerController := preload("res://scripts/player/player_controller.gd")
const DELTA := 0.1
# One physics frame at 60 a second.
const FRAME := 1.0 / 60.0
# How many frames the rig's slash plays before it reports finishing: 0.2 seconds.
const SLASH_FRAMES := 12


func get_tests() -> Array:
	return [
		["Pressing melee slashes at once", _test_press_slashes],
		["A quick tap slashes once, with no Charge", _test_tap_slashes_once],
		["Melee held through the slash goes into the Charge", _test_held_into_charge],
		["A full Charge is half a second from the press", _test_full_from_the_press],
		["Letting go short of a full Charge ends it, with no swing", _test_short_charge_ends],
		["Letting go of a full Charge swings a charged Attack", _test_full_charge_swings],
		["Controller locks attack until it finishes", _test_locks_attack_until_finished],
		["Controller ends attack by floor contact", _test_ends_attack_by_floor_contact],
		["Controller attacks in the air", _test_attacks_in_air],
		["Controller keeps a Charge through a jump", _test_keeps_charge_through_jump],
	]


func _test_press_slashes() -> bool:
	var controller := PlayerController.new()
	_step(controller, true)
	var valid := controller.state == PlayerController.State.ATTACK
	return valid and not controller.charged_attack and not controller.is_fully_charged()


# Pressed for a few frames and let go: one slash, and never a Charge.
func _test_tap_slashes_once() -> bool:
	var controller := PlayerController.new()
	var entered: Array = []
	controller.state_changed.connect(
		func(_previous: PlayerController.State, next: PlayerController.State) -> void:
			entered.append(next)
	)
	for i in 6:
		_step(controller, true)
	for i in SLASH_FRAMES - 6:
		_step(controller, false)
	_step(controller, false, true)
	var valid := controller.state == PlayerController.State.IDLE
	valid = valid and entered.count(PlayerController.State.ATTACK) == 1
	return valid and not entered.has(PlayerController.State.CHARGE)


func _test_held_into_charge() -> bool:
	var controller := PlayerController.new()
	_slash_into_charge(controller)
	var valid := controller.state == PlayerController.State.CHARGE
	valid = valid and not controller.charged_attack
	# Movement carries on while charging, and facing stays put.
	var frame := _next_frame(controller)
	frame.melee_held = true
	frame.direction = 1.0
	controller.step(frame, FRAME)
	valid = valid and controller.state == PlayerController.State.CHARGE
	valid = valid and controller.velocity.x > 0.0 and controller.is_moving
	return valid and controller.facing == -1.0


# The slash's time counts toward filling the Charge.
func _test_full_from_the_press() -> bool:
	var controller := PlayerController.new()
	var held := 0.0
	var frames := 0
	while not controller.is_fully_charged() and held < 1.0:
		frames += 1
		_step(controller, true, frames == SLASH_FRAMES)
		held += FRAME
	return absf(held - controller.charge_time) < FRAME * 1.5


func _test_short_charge_ends() -> bool:
	var controller := PlayerController.new()
	_slash_into_charge(controller)
	_step(controller, false)
	return controller.state == PlayerController.State.IDLE and not controller.charged_attack


func _test_full_charge_swings() -> bool:
	var controller := PlayerController.new()
	_slash_into_charge(controller)
	_hold(controller, controller.charge_time)
	var valid := controller.is_fully_charged()
	_step(controller, false)
	valid = valid and controller.state == PlayerController.State.ATTACK
	valid = valid and controller.charged_attack
	_step(controller, false, true)
	valid = valid and controller.state == PlayerController.State.IDLE
	# The next press slashes plainly again.
	_step(controller, true)
	return (
		valid
		and controller.state == PlayerController.State.ATTACK
		and not controller.charged_attack
	)


func _test_locks_attack_until_finished() -> bool:
	var controller := PlayerController.new()
	_step(controller, true, false, DELTA)
	var frame := _next_frame(controller)
	frame.velocity = Vector2(200.0, 0.0)
	frame.direction = 1.0
	frame.jump_pressed = true
	frame.melee_held = true
	controller.step(frame, DELTA)
	var valid := controller.state == PlayerController.State.ATTACK
	valid = valid and controller.facing == -1.0
	valid = valid and controller.velocity.x == 200.0 - controller.friction * DELTA
	return valid and controller.velocity.y == 0.0


func _test_ends_attack_by_floor_contact() -> bool:
	var grounded := PlayerController.new()
	_step(grounded, true)
	_step(grounded, false, true)
	var airborne := PlayerController.new()
	_step(airborne, true)
	var frame := _next_frame(airborne)
	frame.attack_finished = true
	frame.on_floor = false
	airborne.step(frame, FRAME)
	return (
		grounded.state == PlayerController.State.IDLE
		and airborne.state == PlayerController.State.JUMP
	)


func _test_attacks_in_air() -> bool:
	var controller := PlayerController.new()
	var frame := _next_frame(controller)
	frame.on_floor = false
	frame.melee_held = true
	frame.velocity = Vector2(200.0, 0.0)
	controller.step(frame, DELTA)
	var valid := controller.state == PlayerController.State.ATTACK
	frame = _next_frame(controller)
	frame.on_floor = false
	frame.direction = 1.0
	controller.step(frame, DELTA)
	return valid and controller.velocity.x == 200.0 - 2.0 * controller.friction * DELTA


func _test_keeps_charge_through_jump() -> bool:
	var controller := PlayerController.new()
	_slash_into_charge(controller)
	_hold(controller, controller.charge_time)
	var frame := _next_frame(controller)
	frame.melee_held = true
	frame.jump_pressed = true
	controller.step(frame, FRAME)
	var valid := controller.state == PlayerController.State.CHARGE
	valid = valid and controller.velocity.y == controller.jump_velocity
	return valid and controller.is_fully_charged()


# Presses melee and holds it until the slash finishes, into the Charge.
func _slash_into_charge(controller: PlayerController) -> void:
	_step(controller, true)
	_step(controller, true, true)


func _hold(controller: PlayerController, time: float) -> void:
	for i in ceili(time / FRAME) + 1:
		_step(controller, true)


func _step(
	controller: PlayerController, melee_held: bool, attack_finished := false, delta := FRAME
) -> void:
	var frame := _next_frame(controller)
	frame.melee_held = melee_held
	frame.attack_finished = attack_finished
	controller.step(frame, delta)


func _next_frame(controller: PlayerController) -> PlayerController.Frame:
	var frame := PlayerController.Frame.new()
	frame.velocity = controller.velocity
	return frame
