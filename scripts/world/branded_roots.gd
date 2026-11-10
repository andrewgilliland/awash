extends StaticBody2D

# Branded roots: a wall of roots glowing with Rusk's brand, standing up from their foot. They wait
# down in the floor, unseen, burst up when he calls them and shut the way, and wither and sink
# when he leaps away.

const RISE_TIME := 0.4
const WITHER_TIME := 1.0
const HEIGHT := 112.0
# Withering, they darken as they sink.
const WITHERED := Color(0.35, 0.3, 0.3)

var _up: bool = false
# Counting down while rising or withering; zero otherwise.
var _rise_left: float = 0.0
var _wither_left: float = 0.0

@onready var _shape: CollisionShape2D = $Shape
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _rise_sound: AudioStreamPlayer2D = $Sounds/Rise
@onready var _wither_sound: AudioStreamPlayer2D = $Sounds/Wither


func _ready() -> void:
	_lie_down()


func is_up() -> bool:
	return _up


func rise() -> void:
	_up = true
	_wither_left = 0.0
	_rise_left = RISE_TIME
	_shape.disabled = false
	modulate = Color.WHITE
	show()
	_stand(0.0)
	_rise_sound.play()


func wither() -> void:
	if not _up:
		return
	_up = false
	_rise_left = 0.0
	_wither_left = WITHER_TIME
	_stand(HEIGHT)
	_wither_sound.play()


func _process(delta: float) -> void:
	if _rise_left > 0.0:
		_rise_left = maxf(_rise_left - delta, 0.0)
		_stand(HEIGHT * (1.0 - _rise_left / RISE_TIME))
	elif _wither_left > 0.0:
		_wither_left = maxf(_wither_left - delta, 0.0)
		var left := _wither_left / WITHER_TIME
		_stand(HEIGHT * left)
		modulate = WITHERED.lerp(Color.WHITE, left)
		if _wither_left <= 0.0:
			_lie_down()


# Up out of the floor to this height, the roots' tips first.
func _stand(height: float) -> void:
	# An empty region would draw the whole sheet, so at least a pixel shows.
	_sprite.region_rect = Rect2(0.0, 0.0, _sprite.region_rect.size.x, maxf(height, 1.0))
	_sprite.position.y = -height


func _lie_down() -> void:
	_shape.disabled = true
	hide()
