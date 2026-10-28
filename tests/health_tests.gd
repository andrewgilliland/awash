extends RefCounted

const Health := preload("res://scripts/combat/health.gd")


func get_tests() -> Array:
	return [
		["Health starts full", _test_starts_full],
		["A hit costs Health", _test_hit_costs_health],
		["Invulnerability blocks hits until it wears off", _test_invulnerability_blocks_hits],
		["Health stops at zero and is defeated", _test_stops_at_zero],
		["Defeated Health ignores hits", _test_defeated_ignores_hits],
	]


func _test_starts_full() -> bool:
	var health := Health.new(3)
	return health.current == 3 and health.maximum == 3 and not health.is_defeated()


func _test_hit_costs_health() -> bool:
	var health := Health.new(3)
	var landed := health.hurt(1, 0.0)
	return landed and health.current == 2


func _test_invulnerability_blocks_hits() -> bool:
	var health := Health.new(3)
	health.hurt(1, 0.5)
	var valid := not health.hurt(1, 0.5) and health.current == 2
	health.step(0.3)
	valid = valid and not health.hurt(1, 0.5) and health.current == 2
	health.step(0.3)
	valid = valid and health.hurt(1, 0.5) and health.current == 1
	return valid


func _test_stops_at_zero() -> bool:
	var health := Health.new(2)
	health.hurt(5, 0.0)
	return health.current == 0 and health.is_defeated()


func _test_defeated_ignores_hits() -> bool:
	var health := Health.new(1)
	health.hurt(1, 0.0)
	return not health.hurt(1, 0.0) and health.current == 0
