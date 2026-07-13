extends RefCounted

var _player: CharacterBody2D = null
var _attack_area: Area2D = null
var _attack_shape: CollisionShape2D = null
var _state_values: Dictionary = {}
var _phase_values: Dictionary = {}
var _attack_phase_timer: float = 0.0
var _attack_hit_targets: Dictionary = {}


# Sets up runtime dependencies.
func setup(
	player: CharacterBody2D,
	attack_area: Area2D,
	attack_shape: CollisionShape2D,
	state_values: Dictionary,
	phase_values: Dictionary
) -> void:
	_player = player
	_attack_area = attack_area
	_attack_shape = attack_shape
	_state_values = state_values
	_phase_values = phase_values
	_attack_phase_timer = 0.0
	_attack_hit_targets.clear()


# Sets attack hitbox enabled.
func set_attack_hitbox_enabled(enabled: bool) -> void:
	if _attack_shape != null:
		_attack_shape.disabled = not enabled
	if _attack_area != null:
		_attack_area.monitoring = enabled


# Updates attack hitbox orientation.
func update_attack_hitbox_orientation() -> void:
	if _attack_area == null:
		return

	var direction := 1.0 if _player._facing_sign >= 0.0 else -1.0
	_attack_area.position = Vector2(
		_player._attack_base_position.x * direction, _player._attack_base_position.y
	)


# Handles attack press.
func handle_attack_press() -> void:
	if _player._state == _state(&"dead"):
		return
	if _player._state == _state(&"hurt"):
		return
	if _player._state == _state(&"guard"):
		return

	if _player._attack_phase != _phase(&"none"):
		return

	if Input.is_action_pressed("melee_attack"):
		if _player.is_on_floor():
			_player._set_state(_state(&"charge"))
		return

	if _player._state == _state(&"charge"):
		_begin_attack()


# Attempts to fire projectile.
func try_fire_projectile() -> void:
	var blocked_state: bool = _player._state == _state(&"dead") or _player._state == _state(&"hurt")
	blocked_state = blocked_state or _player._state == _state(&"guard")
	blocked_state = blocked_state or _player._state == _state(&"charge")
	if blocked_state:
		return

	if _player.projectile_scene == null:
		return

	if _player._ranged_cooldown_timer > 0.0:
		_player.emit_signal("feedback_event_requested", "ranged_cooldown_blocked")
		return

	if _player._ranged_resource < _player.ranged_cost:
		_player.emit_signal("feedback_event_requested", "ranged_resource_empty")
		return

	var projectile := _player.projectile_scene.instantiate() as Node2D
	if projectile == null:
		return

	var scene_root := _player.get_tree().current_scene
	if scene_root == null:
		projectile.queue_free()
		return

	projectile.global_position = _player.global_position
	projectile.global_position += Vector2(
		_player.projectile_spawn_offset.x * _player._facing_sign, _player.projectile_spawn_offset.y
	)

	if projectile.has_method("initialize"):
		projectile.call("initialize", _player._facing_sign, _player)

	_try_set_projectile_property(projectile, "speed", _player.projectile_speed)
	_try_set_projectile_property(
		projectile, "lifetime_seconds", _player.projectile_lifetime_seconds
	)
	_try_set_projectile_property(projectile, "damage", _player.projectile_damage)
	_try_set_projectile_property(projectile, "knockback", _player.projectile_knockback)

	scene_root.add_child(projectile)

	_player._ranged_resource = maxf(0.0, _player._ranged_resource - _player.ranged_cost)
	_player._ranged_cooldown_timer = _player.ranged_cooldown_seconds
	_player.emit_signal("feedback_event_requested", "ranged_fire")


# Advances attack phase over delta time.
func tick_attack_phase(delta: float) -> void:
	if _player._attack_phase == _phase(&"none"):
		return

	_attack_phase_timer = maxf(0.0, _attack_phase_timer - delta)
	if _attack_phase_timer > 0.0:
		return

	if _player._attack_phase == _phase(&"startup"):
		_player._attack_phase = _phase(&"active")
		_attack_phase_timer = _player.melee_active_seconds
		_attack_hit_targets.clear()
		set_attack_hitbox_enabled(true)
		_player._emit_attack_window_started()
		_player.emit_signal("feedback_event_requested", "melee_active")
		return

	if _player._attack_phase == _phase(&"active"):
		_player._attack_phase = _phase(&"recovery")
		_attack_phase_timer = _player.melee_recovery_seconds
		set_attack_hitbox_enabled(false)
		_player._emit_attack_window_ended()
		_player.emit_signal("feedback_event_requested", "melee_recovery")
		return

	end_attack()


# Ends attack.
func end_attack() -> void:
	_player._attack_phase = _phase(&"none")
	_attack_phase_timer = 0.0
	_attack_hit_targets.clear()
	set_attack_hitbox_enabled(false)
	if _player._state == _state(&"attack"):
		_player._update_state_from_motion()


# Handles attack area body entered.
func on_attack_area_body_entered(body: Node2D) -> void:
	_register_melee_hit(body)


# Handles attack area area entered.
func on_attack_area_area_entered(area: Area2D) -> void:
	if area == null:
		return

	if area.get_parent() != null:
		_register_melee_hit(area.get_parent())


# Begins attack.
func _begin_attack() -> void:
	_player._set_state(_state(&"attack"))
	_player._attack_phase = _phase(&"startup")
	_attack_phase_timer = _player.melee_startup_seconds
	_attack_hit_targets.clear()
	set_attack_hitbox_enabled(false)
	_player.emit_signal("feedback_event_requested", "melee_startup")


# Registers melee hit.
func _register_melee_hit(target: Node) -> void:
	if target == null:
		return

	if _player._attack_phase != _phase(&"active"):
		return

	if _attack_hit_targets.has(target):
		return

	_attack_hit_targets[target] = true

	if target.has_method("take_damage"):
		var knockback := Vector2(
			_player.melee_knockback.x * _player._facing_sign, _player.melee_knockback.y
		)
		target.call("take_damage", _player.melee_damage, knockback)

	_player._emit_melee_hit_confirmed(target)
	_player.emit_signal("feedback_event_requested", "melee_hit_confirm")


# Attempts to set projectile property.
func _try_set_projectile_property(
	projectile: Object, property_name: StringName, value: Variant
) -> void:
	for property_data in projectile.get_property_list():
		if property_data.has("name") and property_data["name"] == property_name:
			projectile.set(property_name, value)
			return


# Looks up a combat state enum value by its canonical name key.
func _state(key: StringName) -> int:
	return int(_state_values[key])


# Looks up a combat phase enum value by its canonical name key.
func _phase(key: StringName) -> int:
	return int(_phase_values[key])
