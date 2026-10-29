extends RefCounted

const WraithBrain := preload("res://scripts/enemies/wraith_brain.gd")
# Each names an AudioStreamPlayer2D under the Wraith's Sounds node.
const WAIL := &"Wail"
const LASH := &"Lash"
const HURT := &"Hurt"
const DEFEAT := &"Defeat"
# The sound of entering each state; the others are quiet.
const ON_ENTER := {
	WraithBrain.State.MANIFEST: WAIL,
	WraithBrain.State.LASH: LASH,
	WraithBrain.State.HURT: HURT,
	WraithBrain.State.DEFEATED: DEFEAT,
}

var _players: Node


func _init(players: Node) -> void:
	_players = players


# The sound a state change makes, or none. The wail is the Player's warning that a lash is
# coming.
static func for_state_change(_previous: WraithBrain.State, next: WraithBrain.State) -> StringName:
	return ON_ENTER.get(next, &"")


func play(sound: StringName) -> void:
	if sound.is_empty() or _players == null:
		return
	var stream_player := _players.get_node_or_null(NodePath(sound)) as AudioStreamPlayer2D
	if stream_player != null:
		stream_player.play()
