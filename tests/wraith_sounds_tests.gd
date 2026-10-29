extends RefCounted

const WraithBrain := preload("res://scripts/enemies/wraith_brain.gd")
const WraithSounds := preload("res://scripts/enemies/wraith_sounds.gd")


func get_tests() -> Array:
	return [
		["Wraith wails as it manifests", _test_wail],
		["Wraith's lash whooshes", _test_lash],
		["Wraith cracks when hurt, from any state", _test_hurt],
		["Wraith sighs away when defeated, from any state", _test_defeat],
		["Wraith drifts and shows its anchor quietly", _test_quiet],
	]


func _test_wail() -> bool:
	return (
		WraithSounds.for_state_change(WraithBrain.State.DRIFT, WraithBrain.State.MANIFEST)
		== WraithSounds.WAIL
	)


func _test_lash() -> bool:
	return (
		WraithSounds.for_state_change(WraithBrain.State.MANIFEST, WraithBrain.State.LASH)
		== WraithSounds.LASH
	)


func _test_hurt() -> bool:
	var valid := true
	for previous in [
		WraithBrain.State.DRIFT,
		WraithBrain.State.MANIFEST,
		WraithBrain.State.LASH,
		WraithBrain.State.EXPOSED
	]:
		valid = (
			valid
			and WraithSounds.for_state_change(previous, WraithBrain.State.HURT) == WraithSounds.HURT
		)
	return valid


func _test_defeat() -> bool:
	var valid := true
	for previous in [WraithBrain.State.DRIFT, WraithBrain.State.EXPOSED, WraithBrain.State.HURT]:
		valid = (
			valid
			and (
				WraithSounds.for_state_change(previous, WraithBrain.State.DEFEATED)
				== WraithSounds.DEFEAT
			)
		)
	return valid


func _test_quiet() -> bool:
	var valid := (
		WraithSounds.for_state_change(WraithBrain.State.LASH, WraithBrain.State.EXPOSED) == &""
	)
	valid = (
		valid
		and WraithSounds.for_state_change(WraithBrain.State.EXPOSED, WraithBrain.State.DRIFT) == &""
	)
	return (
		valid
		and WraithSounds.for_state_change(WraithBrain.State.HURT, WraithBrain.State.DRIFT) == &""
	)
