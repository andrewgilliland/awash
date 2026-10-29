extends RefCounted

const PlayerController := preload("res://scripts/player/player_controller.gd")
# Each names an AudioStreamPlayer under the Player's Sounds node.
const JUMP := &"Jump"
const LAND := &"Land"
const SWING := &"Swing"
const HIT := &"Hit"
const HURT := &"Hurt"
const DEFEAT := &"Defeat"
const LEVEL_UP := &"LevelUp"
const PICKUP := &"Pickup"
const EAT := &"Eat"
# A landing only sounds after a real fall; a frame in the air, as when the Player appears at
# an Entry, lands quietly.
const MIN_FALL_TIME := 0.08

var _players: Node


func _init(players: Node) -> void:
	_players = players


# The sound a state change makes, or none, given how long the Player was in the state it left.
# Jumps sound through the controller's jumped signal instead, so walking off a ledge or being
# knocked into the air stays quiet.
static func for_state_change(
	previous: PlayerController.State, next: PlayerController.State, time_in_previous: float
) -> StringName:
	var landed := previous == PlayerController.State.JUMP and time_in_previous >= MIN_FALL_TIME
	landed = landed and next in [PlayerController.State.IDLE, PlayerController.State.WALK]
	if landed:
		return LAND
	if next == PlayerController.State.ATTACK:
		return SWING
	return &""


func play(sound: StringName) -> void:
	if sound.is_empty() or _players == null:
		return
	var stream_player := _players.get_node_or_null(NodePath(sound)) as AudioStreamPlayer
	if stream_player != null:
		stream_player.play()
