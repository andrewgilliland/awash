extends RefCounted

signal attack_finished

const PlayerController := preload("res://scripts/player/player_controller.gd")

# The Player's declared look. Frame numbers index one row of cells on each sheet, both drawn
# facing left; sword offsets are per frame, from the body sprite, for a Player facing right.
# The body is the Mucho Pixels character pack's Male Character 3, recoloured as Vael.
const BODY_FRAME_SIZE := Vector2i(64, 48)
const SWORD_FRAME_SIZE := Vector2i(32, 32)
const BLINK_ALPHA := 0.25
const BODY_SHEET := preload("res://assets/player/vael.png")
const SWORD_SHEET := preload("res://assets/player/sword_1.png")
const BODY_ANIMATIONS := {
	&"idle": {frames = [0, 1, 2, 3, 4, 5, 6, 7], fps = 8.0, loop = true},
	&"walk": {frames = [8, 9, 10, 11, 12, 13, 14, 15], fps = 12.0, loop = true},
	&"jump": {frames = [16, 17], fps = 8.0, loop = false},
	&"fall": {frames = [18, 19], fps = 8.0, loop = true},
	&"land": {frames = [20, 21], fps = 12.0, loop = false},
	&"charge": {frames = [22], fps = 1.0, loop = true},
	&"attack": {frames = [23, 24], fps = 10.0, loop = false},
	&"hurt": {frames = [28, 29], fps = 10.0, loop = false},
	&"defeat": {frames = [30, 31, 32, 33, 34, 35, 36], fps = 10.0, loop = false},
}
# The sword sits in the hand: drawn back over the shoulder through a Charge (frame 2), then raised
# and thrust ahead in the swing (frames 0 and 1).
const SWORD_ANIMATIONS := {
	&"charge": {frames = [2], fps = 1.0, loop = true, offsets = [Vector2(-13, 6)]},
	&"attack":
	{
		frames = [0, 1],
		fps = 10.0,
		loop = false,
		offsets = [Vector2(14, 0), Vector2(16, 2)],
	},
}
# What each Player state shows; an empty sword hides it. A jump falling shows `fall`.
const SHOWN := {
	PlayerController.State.IDLE: {body = &"idle", body_moving = &"idle", sword = &""},
	PlayerController.State.WALK: {body = &"walk", body_moving = &"walk", sword = &""},
	PlayerController.State.JUMP: {body = &"jump", body_moving = &"jump", sword = &""},
	PlayerController.State.CHARGE: {body = &"charge", body_moving = &"walk", sword = &"charge"},
	PlayerController.State.ATTACK: {body = &"attack", body_moving = &"attack", sword = &"attack"},
}

var _body: AnimatedSprite2D
var _sword: AnimatedSprite2D
var _shown_state: int = -1
var _facing: float = -1.0
# Poses that play out over the states: a landing, a hurt, and lying down.
var _landing: bool = false
var _hurting: bool = false
var _lying: bool = false


func _init(body: AnimatedSprite2D, sword: AnimatedSprite2D) -> void:
	_body = body
	_sword = sword
	_body.sprite_frames = _build_sprite_frames(BODY_SHEET, BODY_ANIMATIONS, BODY_FRAME_SIZE)
	_sword.sprite_frames = _build_sprite_frames(SWORD_SHEET, SWORD_ANIMATIONS, SWORD_FRAME_SIZE)
	_sword.visible = false
	_body.animation_finished.connect(_on_body_animation_finished)
	_sword.frame_changed.connect(_place_sword)


# Draws the sword in hand from a Weapon's sheet, keeping whatever it is showing.
func hold(sheet: Texture2D) -> void:
	var animation := _sword.animation
	var frame := _sword.frame
	var playing := _sword.is_playing()
	_sword.sprite_frames = _build_sprite_frames(sheet, SWORD_ANIMATIONS, SWORD_FRAME_SIZE)
	if _sword.sprite_frames.has_animation(animation):
		_sword.animation = animation
		_sword.frame = frame
		if playing:
			_sword.play()


# Shows the Player for one step. Animations start only when the state changes, so a held
# state keeps playing; the charge pose, mirroring and sword placement follow every call. A jump
# lands before standing still, and a hurt or lying down holds the body until it is over.
func show(
	state: PlayerController.State, facing: float, is_moving: bool, falling: bool = false
) -> void:
	var row: Dictionary = SHOWN[state]
	var landed := _shown_state == PlayerController.State.JUMP and state != _shown_state
	var state_changed := state != _shown_state
	_shown_state = state
	_facing = facing

	if state_changed:
		_show_sword(row.sword)
	var pose: StringName = row.body_moving if is_moving else row.body
	if state == PlayerController.State.JUMP and falling:
		pose = &"fall"
	if landed and pose == &"idle" and not (_lying or _hurting):
		_landing = true
		_body.play(&"land")
	elif state_changed:
		_landing = false
	if not (_lying or _hurting or _landing) and (state_changed or _body.animation != pose):
		_body.play(pose)

	_body.flip_h = facing > 0.0
	_sword.flip_h = _body.flip_h
	_place_sword()


# Plays the hurt pose over whatever the Player is doing, until it ends.
func show_hurt() -> void:
	_hurting = true
	_body.play(&"hurt")


# Lies the Player down, falling as a defeat does or already down, or stands it back up.
func show_lying(lying: bool, at_once: bool = false) -> void:
	if lying == _lying:
		return
	_lying = lying
	_hurting = false
	_landing = false
	if lying:
		_body.play(&"defeat")
		if at_once:
			_body.frame = _body.sprite_frames.get_frame_count(&"defeat") - 1
			_body.pause()
	else:
		_shown_state = -1
		_body.play(&"idle")


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
	_hurting = false
	_landing = false
	if _shown_state == PlayerController.State.ATTACK and _body.animation == &"attack":
		attack_finished.emit()


func _build_sprite_frames(sheet: Texture2D, animations: Dictionary, cell: Vector2i) -> SpriteFrames:
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
			frame.region = Rect2(Vector2(frame_index * cell.x, 0), Vector2(cell))
			sprite_frames.add_frame(animation_name, frame)
	return sprite_frames
