extends RefCounted

const PirateBrain := preload("res://scripts/enemies/pirate_brain.gd")
# Each names an AudioStreamPlayer2D under the Pirate's Sounds node.
const WHISTLE := &"Whistle"
const SWISH := &"Swish"
const GRUNT := &"Grunt"
const DEFEAT := &"Defeat"

var _players: Node


func _init(players: Node) -> void:
	_players = players


# The sound a state change makes, or none: a swish as its cutlass rushes, a grunt as a hit
# flinches it, a cry at its defeat. Its whistle comes as it notices the Player, not with a state.
static func for_state_change(previous: PirateBrain.State, next: PirateBrain.State) -> StringName:
	if next == PirateBrain.State.DEFEATED:
		return DEFEAT
	if next == PirateBrain.State.HURT:
		return GRUNT
	if next == PirateBrain.State.RUSH and previous != next:
		return SWISH
	return &""


func play(sound: StringName) -> void:
	if sound.is_empty() or _players == null:
		return
	var stream_player := _players.get_node_or_null(NodePath(sound)) as AudioStreamPlayer2D
	if stream_player != null:
		stream_player.play()
