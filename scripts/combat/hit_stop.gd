extends Node

# Freezes play for a few frames when a blow connects, so it is felt. Each Room keeps one; anything
# that lands a blow asks it through request(). Frozen, play runs at a hundredth of its speed, too
# slow to see move; the freeze is timed in frames of play at 60 a second, worked back from that,
# so it lasts as long on a fast screen as on a slow one, and as many frames in a playtest. The
# frame the blow lands in had its time set before play slowed, so it counts as it comes.

const GROUP := &"hit_stop"
# One frame of play at 60 frames a second.
const FRAME_TIME := 1.0 / 60.0
# How fast play runs while frozen.
const FROZEN_SCALE := 0.01

# Seconds of play, at full speed, the freeze has left.
var _left: float = 0.0
# Whether the next frame's time was set before play slowed: the frame the blow landed in.
var _full_speed_frame: bool = false


func _init() -> void:
	add_to_group(GROUP)
	process_mode = Node.PROCESS_MODE_ALWAYS


# Asks the Room's hit-stop, if there is one, to freeze play.
static func request(from: Node, frames: int) -> void:
	if from == null or not from.is_inside_tree():
		return
	var stop := from.get_tree().get_first_node_in_group(GROUP)
	if stop != null:
		stop.call("stop", frames)


# Freezes play for this many frames, unless it is already frozen for longer.
func stop(frames: int) -> void:
	_left = maxf(_left, frames * FRAME_TIME)
	if _left > 0.0 and Engine.time_scale != FROZEN_SCALE:
		Engine.time_scale = FROZEN_SCALE
		_full_speed_frame = true


func is_frozen() -> bool:
	return _left > 0.0


func frames_left() -> int:
	return ceili(_left / FRAME_TIME - 0.001)


# Lets this much time pass at full speed; play goes on once the freeze has run out.
func step(seconds: float) -> void:
	if _left <= 0.0:
		return
	_left -= seconds
	if _left <= 0.0001:
		_left = 0.0
		Engine.time_scale = 1.0


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	step(delta if _full_speed_frame else delta / FROZEN_SCALE)
	_full_speed_frame = false


func _exit_tree() -> void:
	_left = 0.0
	_full_speed_frame = false
	Engine.time_scale = 1.0
