extends RefCounted

const PlayerController := preload("res://scripts/player/player_controller.gd")
const PlayerSounds := preload("res://scripts/player/player_sounds.gd")
const IDLE := PlayerController.State.IDLE
const WALK := PlayerController.State.WALK
const JUMP := PlayerController.State.JUMP
const CHARGE := PlayerController.State.CHARGE
const ATTACK := PlayerController.State.ATTACK
# Long enough in the previous state to count as a real fall.
const FALL := 0.3


func get_tests() -> Array:
	return [
		["Landing from a jump sounds a landing", _test_landing_sounds],
		["Starting an Attack sounds a swing", _test_attack_sounds],
		["Other state changes are silent", _test_other_changes_silent],
		["A moment in the air lands quietly", _test_brief_air_lands_quietly],
	]


func _test_landing_sounds() -> bool:
	return (
		PlayerSounds.for_state_change(JUMP, IDLE, FALL) == PlayerSounds.LAND
		and PlayerSounds.for_state_change(JUMP, WALK, FALL) == PlayerSounds.LAND
	)


func _test_attack_sounds() -> bool:
	return PlayerSounds.for_state_change(CHARGE, ATTACK, FALL) == PlayerSounds.SWING


# Leaving the ground has no sound of its own: a jump sounds through the controller's jumped
# signal, and walking off a ledge or being knocked into the air should stay quiet.
func _test_other_changes_silent() -> bool:
	var silent := [
		[IDLE, WALK], [WALK, IDLE], [IDLE, JUMP], [WALK, CHARGE], [ATTACK, IDLE], [ATTACK, JUMP]
	]
	var valid := true
	for change in silent:
		valid = valid and PlayerSounds.for_state_change(change[0], change[1], FALL) == &""
	return valid


# Appearing at an Entry spends a frame in the air before the floor is found.
func _test_brief_air_lands_quietly() -> bool:
	return PlayerSounds.for_state_change(JUMP, IDLE, 1.0 / 60.0) == &""
