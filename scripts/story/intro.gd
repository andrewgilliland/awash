extends Node

# Chapter 1's opening, in the first Room on a new game: Vael lies in the surf, gets up, and Mara
# comes in along the beach, pulls his sword out of the sand and brings it over to talk. It plays
# once, when the Run is owed it.

const LIE_TIME := 1.2
# The camera opens on Vael, half a screen in from the screen's west edge; Mara walks in from
# just past that edge.
const HALF_SCREEN := 80.0
const MARA_OFF_SCREEN := 12.0
const PICK_UP_TIME := 0.5
# She holds Blacktide out in front of her, lifted clear of its sand mound.
const HELD_OFFSET := Vector2(7, -9)
const HELD_REGION := Rect2(0, 0, 16, 13)
const DIALOGUE_GROUP := &"dialogue_box"
# The line on which she gives Vael his sword.
const HAND_OVER := &"hand_over"
# Vael does not know his own name yet, so he speaks as "???".
const LINES := [
	["MARA", "Easy. Don't try to stand too fast."],
	["MARA", "You washed in on the black surf."],
	["MARA", "Nobody survives the black surf."],
	["MARA", "This was standing in the sand by you."],
	["MARA", "Here. It's yours.", HAND_OVER],
	["???", "Where... is this?"],
	["MARA", "The Waking Coast. I'm Mara, from Tidefen."],
	["???", "I can't remember my own name."],
	["MARA", "Then the sea took more than your ship."],
	["MARA", "I don't trust what the tide gives back."],
	["MARA", "But I won't leave you to it."],
	["MARA", "Tidefen is east, past the palm shore. Stay close."],
]

var _mara: Node2D
var _sword: Sprite2D
var _carrying: bool = false


func _ready() -> void:
	var run := get_node_or_null("/root/RunState")
	if run == null or not run.get("intro_pending"):
		return
	run.set("intro_pending", false)
	# The Room's own _ready, which adds the dialogue box, runs after its children's.
	_play.call_deferred()


func _process(_delta: float) -> void:
	if _carrying:
		_sword.position = _mara.position + HELD_OFFSET


func _play() -> void:
	var room := get_parent()
	var player := room.get_node("Player")
	_mara = room.get_node("Mara") as Node2D
	_sword = room.get_node("Blacktide") as Sprite2D
	# She ends up where she rests on later Runs.
	var rest_x := _mara.position.x
	player.set("controls_locked", true)
	player.call("set_lying", true)
	_sword.visible = true
	_mara.position.x = mara_start_x(player.position.x)
	await get_tree().create_timer(LIE_TIME).timeout
	player.call("set_lying", false)
	await _mara.call("walk_to", _sword.position.x)
	await get_tree().create_timer(PICK_UP_TIME).timeout
	_sword.region_enabled = true
	_sword.region_rect = HELD_REGION
	_carrying = true
	await _mara.call("walk_to", rest_x)
	var box := get_tree().get_first_node_in_group(DIALOGUE_GROUP)
	box.connect(&"cued", _on_cued)
	box.call("show_lines", LINES)


# Where Mara starts, just off the west edge of the screen the camera opens on Vael at vael_x.
static func mara_start_x(vael_x: float) -> float:
	return vael_x - HALF_SCREEN - MARA_OFF_SCREEN


func _on_cued(cue: StringName) -> void:
	if cue == HAND_OVER:
		_carrying = false
		_sword.visible = false
