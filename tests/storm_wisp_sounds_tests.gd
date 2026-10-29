extends RefCounted

const StormWispBrain := preload("res://scripts/enemies/storm_wisp_brain.gd")
const StormWispSounds := preload("res://scripts/enemies/storm_wisp_sounds.gd")


func get_tests() -> Array:
	return [
		["Storm Wisp crackles as it gathers its charge", _test_crackle],
		["Storm Wisp's arc sounds its zap", _test_zap],
		["Storm Wisp fizzes when hurt, from any state", _test_hurt],
		["Storm Wisp hisses out when defeated, from any state", _test_defeat],
		["Storm Wisp rests and drifts quietly", _test_quiet],
	]


func _test_crackle() -> bool:
	return (
		StormWispSounds.for_state_change(StormWispBrain.State.DRIFT, StormWispBrain.State.CRACKLE)
		== StormWispSounds.CRACKLE
	)


func _test_zap() -> bool:
	return (
		StormWispSounds.for_state_change(StormWispBrain.State.CRACKLE, StormWispBrain.State.ARC)
		== StormWispSounds.ZAP
	)


func _test_hurt() -> bool:
	var valid := true
	for previous in [
		StormWispBrain.State.DRIFT,
		StormWispBrain.State.CRACKLE,
		StormWispBrain.State.ARC,
		StormWispBrain.State.REST
	]:
		valid = (
			valid
			and (
				StormWispSounds.for_state_change(previous, StormWispBrain.State.HURT)
				== StormWispSounds.HURT
			)
		)
	return valid


func _test_defeat() -> bool:
	var valid := true
	for previous in [
		StormWispBrain.State.DRIFT, StormWispBrain.State.CRACKLE, StormWispBrain.State.HURT
	]:
		valid = (
			valid
			and (
				StormWispSounds.for_state_change(previous, StormWispBrain.State.DEFEATED)
				== StormWispSounds.DEFEAT
			)
		)
	return valid


func _test_quiet() -> bool:
	var valid := (
		StormWispSounds.for_state_change(StormWispBrain.State.ARC, StormWispBrain.State.REST) == &""
	)
	valid = (
		valid
		and (
			StormWispSounds.for_state_change(StormWispBrain.State.REST, StormWispBrain.State.DRIFT)
			== &""
		)
	)
	return (
		valid
		and (
			StormWispSounds.for_state_change(StormWispBrain.State.HURT, StormWispBrain.State.DRIFT)
			== &""
		)
	)
