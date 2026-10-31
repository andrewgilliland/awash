extends Control

# The Player's Health on screen: a framed bar in the top-left corner, filled to the share of
# Health left. A hit drops the fill at once; the Health it took lingers as a pale trail, then
# drains down after it. It hides when the Room has no Player.

const PLAYER_GROUP := &"player"
# How long the trail holds after a hit, then how long it takes to drain.
const HOLD_TIME := 0.15
const DRAIN_TIME := 0.5
const FILL_SIZE := Vector2(40, 3)
const PADDING := 2.0
const FRAME_COLOUR := Color("94a5c6")
const BACK_COLOUR := Color("183931")
const FILL_COLOUR := Color("e05040")
const FILL_SHINE := Color("f8a080")
const TRAIL_COLOUR := Color("f8f8f8")

# How big the fill is when full; a wider bar sets its own before it is ready.
var fill_size: Vector2 = FILL_SIZE
# Both -1 until the bar first reads its Health.
var _fill: float = -1.0
var _trail: float = -1.0
var _hold_left: float = 0.0
var _drain_speed: float = 0.0


func _ready() -> void:
	custom_minimum_size = fill_size + Vector2(PADDING, PADDING) * 2.0


func _process(delta: float) -> void:
	var health := _health()
	visible = health != null
	if health == null:
		return
	var share := float(health.get("current")) / maxf(health.get("maximum"), 1.0)
	if _fill < 0.0 or share > _fill:
		# The first look, or Health won back: no trail.
		_trail = share
	elif share < _fill:
		_hold_left = HOLD_TIME
		_drain_speed = (_trail - share) / DRAIN_TIME
	_fill = share
	if _hold_left > 0.0:
		_hold_left -= delta
	else:
		_trail = move_toward(_trail, _fill, _drain_speed * delta)
	queue_redraw()


# The Health the bar shows, or null to hide it: the Player's.
func _health() -> Object:
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) if is_inside_tree() else null
	return player.get("health") if player != null else null


# The share of Health left, which the fill shows.
func fill_fraction() -> float:
	return maxf(_fill, 0.0)


# Where the trail of lost Health ends; the fill's own end once it has drained.
func trail_fraction() -> float:
	return maxf(_trail, fill_fraction())


func _draw() -> void:
	var outer := Rect2(Vector2.ZERO, custom_minimum_size)
	draw_rect(outer, BACK_COLOUR)
	draw_rect(outer.grow(-0.5), FRAME_COLOUR, false, 1.0)
	var at := Vector2(PADDING, PADDING)
	var trail_width := roundf(fill_size.x * trail_fraction())
	var fill_width := roundf(fill_size.x * fill_fraction())
	if trail_width > fill_width:
		draw_rect(Rect2(at, Vector2(trail_width, fill_size.y)), TRAIL_COLOUR)
	if fill_width > 0.0:
		draw_rect(Rect2(at, Vector2(fill_width, fill_size.y)), FILL_COLOUR)
		draw_rect(Rect2(at, Vector2(fill_width, 1)), FILL_SHINE)
