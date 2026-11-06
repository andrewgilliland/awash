extends Node

# Shakes the camera it sits on: a jolt of whole pixels that settles to nothing, so the pixel art
# never shimmers. Anything big enough to shake the screen asks it through request().

const GROUP := &"camera_shake"

var _strength: int = 0
var _duration: float = 0.0
var _left: float = 0.0
var _random := RandomNumberGenerator.new()

@onready var _camera: Camera2D = get_parent() as Camera2D


func _init() -> void:
	add_to_group(GROUP)
	_random.seed = 7


# Asks the camera's shake, if there is one, to shake.
static func request(from: Node, pixels: int, seconds: float) -> void:
	if from == null or not from.is_inside_tree():
		return
	var shake := from.get_tree().get_first_node_in_group(GROUP)
	if shake != null:
		shake.call("shake", pixels, seconds)


# Shakes up to this many pixels either way, settling over this long, unless already shaking
# harder.
func shake(pixels: int, seconds: float) -> void:
	if pixels < strength():
		return
	_strength = pixels
	_duration = seconds
	_left = seconds


# How many pixels it shakes by now.
func strength() -> int:
	if _left <= 0.0 or _duration <= 0.0:
		return 0
	return ceili(_strength * _left / _duration)


func time_left() -> float:
	return _left


func _process(delta: float) -> void:
	if _camera == null:
		return
	_left = maxf(_left - delta, 0.0)
	var reach := strength()
	_camera.offset = Vector2(_random.randi_range(-reach, reach), _random.randi_range(-reach, reach))
