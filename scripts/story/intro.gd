extends Node

# Chapter 1's opening, in the first Room on a new game: Vael lies in the surf by the wreck,
# gets up, and Mara comes over to talk. It plays once, when the Run is owed it.

const LIE_TIME := 1.2
# Mara starts at the tidal pool's edge and stops beside Vael.
const MARA_START_X := 60.0
const MARA_STOP_X := 28.0
const DIALOGUE_GROUP := &"dialogue_box"
# Vael does not know his own name yet, so he speaks as "???".
const LINES := [
	["MARA", "Easy. Don't try to stand too fast."],
	["MARA", "You washed in on the black surf."],
	["MARA", "Nobody survives the black surf."],
	["MARA", "And you held on to that sword the whole way."],
	["???", "Where... is this?"],
	["MARA", "The Waking Coast. I'm Mara, from Tidefen."],
	["???", "I can't remember my own name."],
	["MARA", "Then the sea took more than your ship."],
	["MARA", "I don't trust what the tide gives back."],
	["MARA", "But I won't leave you to it."],
	["MARA", "Tidefen is east, past the rune shore. Stay close."],
]


func _ready() -> void:
	var run := get_node_or_null("/root/RunState")
	if run == null or not run.get("intro_pending"):
		return
	run.set("intro_pending", false)
	# The Room's own _ready, which adds the dialogue box, runs after its children's.
	_play.call_deferred()


func _play() -> void:
	var room := get_parent()
	var player := room.get_node("Player")
	var mara := room.get_node("Mara") as Node2D
	player.set("controls_locked", true)
	player.call("set_lying", true)
	mara.position.x = MARA_START_X
	await get_tree().create_timer(LIE_TIME).timeout
	player.call("set_lying", false)
	await mara.call("walk_to", MARA_STOP_X)
	var box := get_tree().get_first_node_in_group(DIALOGUE_GROUP)
	box.call("show_lines", LINES)
