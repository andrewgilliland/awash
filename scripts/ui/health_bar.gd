extends Control

# The Player's Health on screen: a small framed bar in the top-left corner with one segment
# per point. A segment lost to a hit flashes, then empties. It hides when the Room has no
# Player.

enum { FULL, LOST, EMPTY }

const PLAYER_GROUP := &"player"
const FLASH_TIME := 0.5
const FLASH_BLINK := 0.08
const SEGMENT := Vector2(7, 5)
const GAP := 1.0
const PADDING := 2.0
const FRAME_COLOUR := Color("94a5c6")
const BACK_COLOUR := Color("002838")
const FULL_COLOUR := Color("e05040")
const FULL_SHINE := Color("f8a080")
const EMPTY_COLOUR := Color("183931")
const LOST_COLOUR := Color("f8f8f8")

var _shown: int = -1
var _maximum: int = 0
# The segments the last hit took, from and up to (not including), while they flash.
var _lost := Vector2i.ZERO
var _flash_left: float = 0.0


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) if is_inside_tree() else null
	var health: Object = player.get("health") if player != null else null
	visible = health != null
	if health == null:
		return
	var current: int = health.get("current")
	_maximum = health.get("maximum")
	_flash_left = maxf(_flash_left - delta, 0.0)
	if _shown >= 0 and current < _shown:
		_lost = Vector2i(current, _shown)
		_flash_left = FLASH_TIME
	elif current > _shown:
		_flash_left = 0.0
	_shown = current
	custom_minimum_size = _size_for(_maximum)
	queue_redraw()


# What each segment shows, left to right.
func segments() -> Array:
	var states := []
	for i in _maximum:
		if i < _shown:
			states.append(FULL)
		elif _flash_left > 0.0 and i >= _lost.x and i < _lost.y:
			states.append(LOST)
		else:
			states.append(EMPTY)
	return states


func _draw() -> void:
	if _maximum == 0:
		return
	var outer := Rect2(Vector2.ZERO, _size_for(_maximum))
	draw_rect(outer, BACK_COLOUR)
	draw_rect(outer.grow(-0.5), FRAME_COLOUR, false, 1.0)
	var lit := fmod(_flash_left, FLASH_BLINK * 2.0) < FLASH_BLINK
	var states := segments()
	for i in states.size():
		var at := Vector2(PADDING + i * (SEGMENT.x + GAP), PADDING)
		var cell := Rect2(at, SEGMENT)
		match states[i]:
			FULL:
				draw_rect(cell, FULL_COLOUR)
				draw_rect(Rect2(at, Vector2(SEGMENT.x, 1)), FULL_SHINE)
			LOST:
				draw_rect(cell, LOST_COLOUR if lit else EMPTY_COLOUR)
			_:
				draw_rect(cell, EMPTY_COLOUR)


static func _size_for(maximum: int) -> Vector2:
	var width := PADDING * 2.0 + maximum * SEGMENT.x + maxi(maximum - 1, 0) * GAP
	return Vector2(width, PADDING * 2.0 + SEGMENT.y)
