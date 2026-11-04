extends RefCounted

const LurelightBrain := preload("res://scripts/enemies/lurelight_brain.gd")
# Each names an AudioStreamPlayer2D under the Lurelight's Sounds node.
const GULP := &"Gulp"
const SNAP := &"Snap"
const HURT := &"Hurt"
const DEFEAT := &"Defeat"
# The sound of entering each state; the others are quiet.
const ON_ENTER := {
	LurelightBrain.State.DIM: GULP,
	LurelightBrain.State.SNAP: SNAP,
	LurelightBrain.State.HURT: HURT,
	LurelightBrain.State.DEFEATED: DEFEAT,
}

var _players: Node


func _init(players: Node) -> void:
	_players = players


# The sound a state change makes, or none. The gulp is the Player's warning that a Snap is
# coming.
static func for_state_change(
	_previous: LurelightBrain.State, next: LurelightBrain.State
) -> StringName:
	return ON_ENTER.get(next, &"")


func play(sound: StringName) -> void:
	if sound.is_empty() or _players == null:
		return
	var stream_player := _players.get_node_or_null(NodePath(sound)) as AudioStreamPlayer2D
	if stream_player != null:
		stream_player.play()
