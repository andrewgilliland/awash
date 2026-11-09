extends RefCounted

const StalkerBrain := preload("res://scripts/enemies/stalker_brain.gd")
# Each names an AudioStreamPlayer2D under the Stalker's Sounds node.
const RUSTLE := &"Rustle"
const POUNCE := &"Pounce"
const HURT := &"Hurt"
const DEFEAT := &"Defeat"
# The sound of entering each state; the others are quiet.
const ON_ENTER := {
	StalkerBrain.State.MARKING: RUSTLE,
	StalkerBrain.State.LEAPING: POUNCE,
	StalkerBrain.State.HURT: HURT,
	StalkerBrain.State.DEFEATED: DEFEAT,
}

var _players: Node


func _init(players: Node) -> void:
	_players = players


# The sound a state change makes, or none. The rustle of the roots is the Player's warning that a
# pounce is coming.
static func for_state_change(_previous: StalkerBrain.State, next: StalkerBrain.State) -> StringName:
	return ON_ENTER.get(next, &"")


func play(sound: StringName) -> void:
	if sound.is_empty() or _players == null:
		return
	var stream_player := _players.get_node_or_null(NodePath(sound)) as AudioStreamPlayer2D
	if stream_player != null:
		stream_player.play()
