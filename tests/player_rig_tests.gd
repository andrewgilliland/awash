extends RefCounted

const PlayerController := preload("res://scripts/player/player_controller.gd")
const PlayerRig := preload("res://scripts/player/player_rig.gd")


# A rig over two standalone sprites, placed like the Player scene places them.
class Rigged:
	var body := AnimatedSprite2D.new()
	var sword := AnimatedSprite2D.new()
	var rig: RefCounted

	func _init() -> void:
		body.position = Vector2(0, -10)
		rig = PlayerRig.new(body, sword)

	func show(state: int, facing: float = -1.0, is_moving: bool = false) -> void:
		rig.call("show", state, facing, is_moving)

	func free_sprites() -> void:
		body.free()
		sword.free()


func get_tests() -> Array:
	return [
		["Rig table has a row for every state", _test_table_has_row_for_every_state],
		["Rig table gives one sword offset per frame", _test_table_gives_offset_per_frame],
		["Rig cuts frames from the sheet row", _test_cuts_frames_from_sheet_row],
		["Rig shows each state's body animation", _test_shows_body_animation_per_state],
		["Rig shows the charge pose by movement", _test_shows_charge_pose_by_movement],
		["Rig keeps a held state's animation going", _test_keeps_held_state_animation],
		["Rig shows the sword only in charge and attack", _test_shows_sword_in_charge_attack],
		["Rig mirrors body and sword by facing", _test_mirrors_by_facing],
		["Rig places the sword per frame and facing", _test_places_sword_per_frame],
		["Rig reports attack finished", _test_reports_attack_finished],
	]


func _test_table_has_row_for_every_state() -> bool:
	var valid := true
	for state in PlayerController.State.values():
		if not PlayerRig.SHOWN.has(state):
			return false
		var row: Dictionary = PlayerRig.SHOWN[state]
		valid = valid and PlayerRig.BODY_ANIMATIONS.has(row.body)
		valid = valid and PlayerRig.BODY_ANIMATIONS.has(row.body_moving)
		valid = valid and (row.sword.is_empty() or PlayerRig.SWORD_ANIMATIONS.has(row.sword))
	return valid


func _test_table_gives_offset_per_frame() -> bool:
	var valid := true
	for animation in PlayerRig.SWORD_ANIMATIONS.values():
		valid = valid and animation.offsets.size() == animation.frames.size()
	return valid


func _test_cuts_frames_from_sheet_row() -> bool:
	var rigged := Rigged.new()
	var valid := _frames_match(rigged.body.sprite_frames, PlayerRig.BODY_ANIMATIONS)
	valid = valid and _frames_match(rigged.sword.sprite_frames, PlayerRig.SWORD_ANIMATIONS)
	rigged.free_sprites()
	return valid


func _test_shows_body_animation_per_state() -> bool:
	var expected := {
		PlayerController.State.IDLE: &"idle",
		PlayerController.State.WALK: &"walk",
		PlayerController.State.JUMP: &"jump",
		PlayerController.State.CHARGE: &"idle",
		PlayerController.State.ATTACK: &"attack",
	}
	var valid := true
	for state in expected:
		var rigged := Rigged.new()
		rigged.show(state)
		valid = valid and rigged.body.animation == expected[state] and rigged.body.is_playing()
		rigged.free_sprites()
	return valid


func _test_shows_charge_pose_by_movement() -> bool:
	var rigged := Rigged.new()
	rigged.show(PlayerController.State.CHARGE, -1.0, true)
	var valid := rigged.body.animation == &"walk"
	rigged.show(PlayerController.State.CHARGE, -1.0, false)
	valid = valid and rigged.body.animation == &"idle"
	valid = valid and rigged.sword.animation == &"charge"
	rigged.free_sprites()
	return valid


func _test_keeps_held_state_animation() -> bool:
	var rigged := Rigged.new()
	rigged.show(PlayerController.State.JUMP)
	rigged.body.frame = 2
	rigged.show(PlayerController.State.JUMP)
	var valid := rigged.body.animation == &"jump" and rigged.body.frame == 2
	rigged.free_sprites()
	return valid


func _test_shows_sword_in_charge_attack() -> bool:
	var rigged := Rigged.new()
	var valid := not rigged.sword.visible
	for state in [
		PlayerController.State.IDLE, PlayerController.State.WALK, PlayerController.State.JUMP
	]:
		rigged.show(state)
		valid = valid and not rigged.sword.visible
	rigged.show(PlayerController.State.CHARGE)
	valid = valid and rigged.sword.visible and rigged.sword.animation == &"charge"
	rigged.show(PlayerController.State.ATTACK)
	valid = valid and rigged.sword.visible and rigged.sword.animation == &"attack"
	valid = valid and rigged.sword.is_playing()
	rigged.show(PlayerController.State.IDLE)
	valid = valid and not rigged.sword.visible and not rigged.sword.is_playing()
	rigged.free_sprites()
	return valid


func _test_mirrors_by_facing() -> bool:
	var rigged := Rigged.new()
	rigged.show(PlayerController.State.CHARGE, 1.0)
	var valid := rigged.body.flip_h and rigged.sword.flip_h
	rigged.show(PlayerController.State.CHARGE, -1.0)
	valid = valid and not rigged.body.flip_h and not rigged.sword.flip_h
	rigged.free_sprites()
	return valid


func _test_places_sword_per_frame() -> bool:
	var rigged := Rigged.new()
	var valid := true
	for facing in [1.0, -1.0]:
		rigged.show(PlayerController.State.CHARGE, facing)
		valid = valid and rigged.sword.position == _sword_position(rigged, &"charge", 0, facing)
		rigged.show(PlayerController.State.ATTACK, facing)
		valid = valid and rigged.sword.position == _sword_position(rigged, &"attack", 0, facing)
		rigged.sword.frame = 1
		valid = valid and rigged.sword.position == _sword_position(rigged, &"attack", 1, facing)
		rigged.show(PlayerController.State.IDLE, facing)
	rigged.free_sprites()
	return valid


func _test_reports_attack_finished() -> bool:
	var rigged := Rigged.new()
	var reports := [0]
	rigged.rig.connect("attack_finished", func() -> void: reports[0] += 1)
	rigged.show(PlayerController.State.JUMP)
	rigged.body.animation_finished.emit()
	var valid: bool = reports[0] == 0
	rigged.show(PlayerController.State.ATTACK)
	rigged.body.animation_finished.emit()
	valid = valid and reports[0] == 1
	rigged.free_sprites()
	return valid


func _sword_position(
	rigged: Rigged, animation_name: StringName, frame_index: int, facing: float
) -> Vector2:
	var offset: Vector2 = PlayerRig.SWORD_ANIMATIONS[animation_name].offsets[frame_index]
	return rigged.body.position + Vector2(offset.x * facing, offset.y)


# Every declared frame is cut from cell `index` of the sheet's single row.
func _frames_match(sprite_frames: SpriteFrames, animations: Dictionary) -> bool:
	var valid := sprite_frames.get_animation_names().size() == animations.size()
	for animation_name in animations:
		var animation: Dictionary = animations[animation_name]
		valid = valid and sprite_frames.get_frame_count(animation_name) == animation.frames.size()
		valid = valid and sprite_frames.get_animation_loop(animation_name) == animation.loop
		valid = valid and sprite_frames.get_animation_speed(animation_name) == animation.fps
		for i in animation.frames.size():
			var texture := sprite_frames.get_frame_texture(animation_name, i) as AtlasTexture
			var size := Vector2(PlayerRig.FRAME_SIZE)
			var region := Rect2(Vector2(animation.frames[i] * size.x, 0), size)
			valid = valid and texture != null and texture.region == region
	return valid
