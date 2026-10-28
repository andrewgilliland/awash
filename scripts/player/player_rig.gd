extends RefCounted

signal attack_finished

const PlayerController := preload("res://scripts/player/player_controller.gd")

# The Player's declared look. Frame numbers index one row of FRAME_SIZE cells on each sheet;
# sword offsets are per frame, from the body sprite, for a Player facing right.
const FRAME_SIZE := Vector2i(16, 16)
const BLINK_ALPHA := 0.25
const BODY_SHEET := preload("res://assets/sprites/player_1.png")
const SWORD_SHEET := preload("res://assets/sprites/weapons/sword_1.png")
const BODY_ANIMATIONS := {
	&"idle": {frames = [0], fps = 1.0, loop = true},
	&"walk": {frames = [0, 1], fps = 8.0, loop = true},
	&"jump": {frames = [2, 3, 4], fps = 8.0, loop = false},
	&"attack": {frames = [5, 6], fps = 10.0, loop = false},
}
const SWORD_ANIMATIONS := {
	&"charge": {frames = [1], fps = 1.0, loop = true, offsets = [Vector2(11, 0)]},
	&"attack":
	{
		frames = [0, 1],
		fps = 10.0,
		loop = false,
		offsets = [Vector2(12, -12), Vector2(16, 0)],
	},
}
# What each Player state shows; an empty sword hides it.
const SHOWN := {
	PlayerController.State.IDLE: {body = &"idle", body_moving = &"idle", sword = &""},
	PlayerController.State.WALK: {body = &"walk", body_moving = &"walk", sword = &""},
	PlayerController.State.JUMP: {body = &"jump", body_moving = &"jump", sword = &""},
	PlayerController.State.CHARGE: {body = &"idle", body_moving = &"walk", sword = &"charge"},
	PlayerController.State.ATTACK: {body = &"attack", body_moving = &"attack", sword = &"attack"},
}

var _body: AnimatedSprite2D
var _sword: AnimatedSprite2D
var _shown_state: int = -1
var _facing: float = -1.0


func _init(body: AnimatedSprite2D, sword: AnimatedSprite2D) -> void:
	_body = body
	_sword = sword
	_body.sprite_frames = _build_sprite_frames(BODY_SHEET, BODY_ANIMATIONS)
	_sword.sprite_frames = _build_sprite_frames(SWORD_SHEET, SWORD_ANIMATIONS)
	_sword.visible = false
	_body.animation_finished.connect(_on_body_animation_finished)
	_sword.frame_changed.connect(_place_sword)


# Shows the Player for one step. Animations start only when the state changes, so a held
# state keeps playing; the charge pose, mirroring and sword placement follow every call.
func show(state: PlayerController.State, facing: float, is_moving: bool) -> void:
	var row: Dictionary = SHOWN[state]
	var state_changed := state != _shown_state
	_shown_state = state
	_facing = facing

	if state_changed:
		_show_sword(row.sword)
	var pose: StringName = row.body_moving if is_moving else row.body
	if state_changed or _body.animation != pose:
		_body.play(pose)

	_body.flip_h = facing > 0.0
	_sword.flip_h = _body.flip_h
	_place_sword()


# Fades the Player out on the off beat of an invulnerable blink.
func show_blink(lit: bool) -> void:
	var alpha := 1.0 if lit else BLINK_ALPHA
	_body.self_modulate.a = alpha
	_sword.self_modulate.a = alpha


func _show_sword(animation_name: StringName) -> void:
	if animation_name.is_empty():
		_sword.stop()
		_sword.visible = false
		return

	_sword.visible = true
	_sword.play(animation_name)


func _place_sword() -> void:
	if not _sword.visible:
		return

	var offset: Vector2 = SWORD_ANIMATIONS[_sword.animation].offsets[_sword.frame]
	_sword.position = _body.position + Vector2(offset.x * _facing, offset.y)


func _on_body_animation_finished() -> void:
	if _shown_state == PlayerController.State.ATTACK:
		attack_finished.emit()


func _build_sprite_frames(sheet: Texture2D, animations: Dictionary) -> SpriteFrames:
	var sprite_frames := SpriteFrames.new()
	sprite_frames.remove_animation(&"default")
	for animation_name in animations:
		var animation: Dictionary = animations[animation_name]
		sprite_frames.add_animation(animation_name)
		sprite_frames.set_animation_loop(animation_name, animation.loop)
		sprite_frames.set_animation_speed(animation_name, animation.fps)
		for frame_index in animation.frames:
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(
				Vector2(frame_index * FRAME_SIZE.x, 0), Vector2(FRAME_SIZE.x, FRAME_SIZE.y)
			)
			sprite_frames.add_frame(animation_name, frame)
	return sprite_frames
