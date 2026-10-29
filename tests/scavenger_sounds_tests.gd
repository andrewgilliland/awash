extends RefCounted

const ScavengerBrain := preload("res://scripts/enemies/scavenger_brain.gd")
const ScavengerSounds := preload("res://scripts/enemies/scavenger_sounds.gd")
const PATROL := ScavengerBrain.State.PATROL
const WINDUP := ScavengerBrain.State.WINDUP
const LUNGE := ScavengerBrain.State.LUNGE
const RECOVER := ScavengerBrain.State.RECOVER
const HURT := ScavengerBrain.State.HURT
const DEFEATED := ScavengerBrain.State.DEFEATED


func get_tests() -> Array:
	return [
		["Scavenger growls as it winds up", _test_windup_sounds],
		["Scavenger's lunge sounds its spear", _test_lunge_sounds],
		["Scavenger croaks when hurt, from any state", _test_hurt_sounds],
		["Scavenger burbles when defeated, from any state", _test_defeat_sounds],
		["Scavenger recovers and patrols quietly", _test_quiet_changes],
	]


func _test_windup_sounds() -> bool:
	return ScavengerSounds.for_state_change(PATROL, WINDUP) == ScavengerSounds.WINDUP


func _test_lunge_sounds() -> bool:
	return ScavengerSounds.for_state_change(WINDUP, LUNGE) == ScavengerSounds.LUNGE


func _test_hurt_sounds() -> bool:
	var valid := true
	for previous in [PATROL, WINDUP, LUNGE, RECOVER]:
		valid = valid and ScavengerSounds.for_state_change(previous, HURT) == ScavengerSounds.HURT
	return valid


func _test_defeat_sounds() -> bool:
	var valid := true
	for previous in [PATROL, WINDUP, LUNGE, RECOVER, HURT]:
		var sound := ScavengerSounds.for_state_change(previous, DEFEATED)
		valid = valid and sound == ScavengerSounds.DEFEAT
	return valid


func _test_quiet_changes() -> bool:
	return (
		ScavengerSounds.for_state_change(LUNGE, RECOVER) == &""
		and ScavengerSounds.for_state_change(RECOVER, PATROL) == &""
		and ScavengerSounds.for_state_change(HURT, PATROL) == &""
	)
