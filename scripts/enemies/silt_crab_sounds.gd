extends RefCounted

const SiltCrabBrain := preload("res://scripts/enemies/silt_crab_brain.gd")
# Each names an AudioStreamPlayer2D under the Silt Crab's Sounds node.
const SKITTER := &"Skitter"
const THUD := &"Thud"
const HURT := &"Hurt"
const DEFEAT := &"Defeat"
# The sound of entering each state; the others are quiet.
const ON_ENTER := {
	SiltCrabBrain.State.SHAKING: SKITTER,
	SiltCrabBrain.State.STUNNED: THUD,
	SiltCrabBrain.State.HURT: HURT,
	SiltCrabBrain.State.DEFEATED: DEFEAT,
}

var _players: Node


func _init(players: Node) -> void:
	_players = players


# The sound a state change makes, or none. The skitter is the Player's warning that a drop is
# coming.
static func for_state_change(
	_previous: SiltCrabBrain.State, next: SiltCrabBrain.State
) -> StringName:
	return ON_ENTER.get(next, &"")


func play(sound: StringName) -> void:
	if sound.is_empty() or _players == null:
		return
	var stream_player := _players.get_node_or_null(NodePath(sound)) as AudioStreamPlayer2D
	if stream_player != null:
		stream_player.play()
