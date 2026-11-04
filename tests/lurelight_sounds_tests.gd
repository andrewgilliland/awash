extends RefCounted

const LurelightBrain := preload("res://scripts/enemies/lurelight_brain.gd")
const LurelightSounds := preload("res://scripts/enemies/lurelight_sounds.gd")


func get_tests() -> Array:
	return [
		["Lurelight gulps as it dims", _test_gulp],
		["Lurelight's Snap splashes and clacks", _test_snap],
		["Lurelight squeals when hit", _test_hurt],
		["Lurelight gurgles when defeated, from any state", _test_defeat],
		["Lurelight lurks, strands and sinks quietly", _test_quiet],
	]


func _test_gulp() -> bool:
	return (
		LurelightSounds.for_state_change(LurelightBrain.State.HIDDEN, LurelightBrain.State.DIM)
		== LurelightSounds.GULP
	)


func _test_snap() -> bool:
	return (
		LurelightSounds.for_state_change(LurelightBrain.State.DIM, LurelightBrain.State.SNAP)
		== LurelightSounds.SNAP
	)


func _test_hurt() -> bool:
	return (
		LurelightSounds.for_state_change(LurelightBrain.State.STRANDED, LurelightBrain.State.HURT)
		== LurelightSounds.HURT
	)


func _test_defeat() -> bool:
	var valid := true
	for previous in [
		LurelightBrain.State.HIDDEN, LurelightBrain.State.STRANDED, LurelightBrain.State.HURT
	]:
		valid = (
			valid
			and (
				LurelightSounds.for_state_change(previous, LurelightBrain.State.DEFEATED)
				== LurelightSounds.DEFEAT
			)
		)
	return valid


func _test_quiet() -> bool:
	var valid := true
	for change in [
		[LurelightBrain.State.SNAP, LurelightBrain.State.STRANDED],
		[LurelightBrain.State.STRANDED, LurelightBrain.State.SUNK],
		[LurelightBrain.State.HURT, LurelightBrain.State.SUNK],
		[LurelightBrain.State.SUNK, LurelightBrain.State.HIDDEN],
	]:
		valid = valid and LurelightSounds.for_state_change(change[0], change[1]) == &""
	return valid
