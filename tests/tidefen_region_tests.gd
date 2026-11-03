extends RefCounted

# Tidefen Village: a small Region of its own past the Warden's gate, and the Safe spoke the Waking
# Coast and the Undertow both lean on. It has its own Map name, colour and theme, and keeps the
# coast's sky and sea and its sheets.

const World := preload("res://scripts/core/world.gd")
const TIDEFEN := &"waking_coast_8"
const COAST_ROOM := &"waking_coast_7"
const COAST_THEME := "res://assets/regions/waking_coast/music/theme.wav"


func get_tests() -> Array:
	return [
		["Tidefen Village is a Region of its own on the Map", _test_region],
		["Tidefen has a calm, looping theme of its own", _test_theme],
		["Tidefen keeps the coast's sky and sea, and draws from its sheets", _test_shares_coast],
		["The Warden's gate stays the coast's last Room before Tidefen", _test_gate_on_coast],
	]


func _test_region() -> bool:
	var region := World.region(TIDEFEN)
	return (
		region == &"tidefen"
		and World.name_of_region(region) == "Tidefen Village"
		and World.colour_of_region(region).a == 1.0
		and World.colour_of_region(region) != World.region_colour(COAST_ROOM)
	)


func _test_theme() -> bool:
	var path := World.theme(TIDEFEN)
	var theme := load(path) as AudioStreamWAV if ResourceLoader.exists(path) else null
	return (
		theme != null
		and theme.loop_mode == AudioStreamWAV.LOOP_FORWARD
		and path.begins_with("res://assets/regions/tidefen/")
		and path != COAST_THEME
	)


func _test_shares_coast() -> bool:
	return (
		World.background(TIDEFEN) == World.background(COAST_ROOM)
		and World.tiles(TIDEFEN) == World.tiles(COAST_ROOM)
	)


func _test_gate_on_coast() -> bool:
	return World.region(COAST_ROOM) == &"waking_coast"
