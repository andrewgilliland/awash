extends RefCounted

const SubWeapons := preload("res://scripts/items/sub_weapons.gd")
const BOMB := &"bomb"


func get_tests() -> Array:
	return [
		["A new Run holds no Sub Weapon and owns none", _test_starts_empty],
		["Every Sub Weapon has a name, a description and an icon", _test_every_kind_described],
		["A Sub Weapon is owned once, and only a known one", _test_own],
		["Only an owned Sub Weapon can be held, or none", _test_hold_owned_only],
		["Up to 9 of an owned Sub Weapon are carried", _test_carries_up_to_nine],
		["Spending one needs one carried", _test_spend],
		["Sub Weapons start from what the Run carried", _test_starts_from_run],
		["A refill tops up every owned Sub Weapon to its limit", _test_refill],
	]


func _test_refill() -> bool:
	var sub_weapons := SubWeapons.new()
	sub_weapons.refill()
	var valid := sub_weapons.count(BOMB) == 0
	sub_weapons.own(BOMB)
	sub_weapons.add(BOMB)
	sub_weapons.refill()
	return valid and sub_weapons.count(BOMB) == SubWeapons.CARRY_LIMIT


func _test_starts_empty() -> bool:
	var sub_weapons := SubWeapons.new()
	var valid := sub_weapons.held == &"" and sub_weapons.owned.is_empty()
	return valid and sub_weapons.held_name() == "None" and sub_weapons.count(BOMB) == 0


func _test_every_kind_described() -> bool:
	if not SubWeapons.KINDS.has(BOMB):
		return false
	for kind: Dictionary in SubWeapons.KINDS.values():
		var described: bool = not kind.name.is_empty() and not kind.description.is_empty()
		if not described or not ResourceLoader.exists(kind.icon):
			return false
	return true


func _test_own() -> bool:
	var sub_weapons := SubWeapons.new()
	var valid := sub_weapons.own(BOMB) and sub_weapons.owns(BOMB)
	valid = valid and not sub_weapons.own(BOMB) and sub_weapons.owned == [BOMB]
	return valid and not sub_weapons.own(&"nothing") and sub_weapons.owned == [BOMB]


func _test_hold_owned_only() -> bool:
	var sub_weapons := SubWeapons.new()
	var valid := not sub_weapons.hold(BOMB) and sub_weapons.held == &""
	sub_weapons.own(BOMB)
	valid = valid and sub_weapons.hold(BOMB) and sub_weapons.held == BOMB
	valid = valid and sub_weapons.held_name() == "Bomb"
	return valid and sub_weapons.hold(&"") and sub_weapons.held == &""


func _test_carries_up_to_nine() -> bool:
	var sub_weapons := SubWeapons.new()
	var valid := not sub_weapons.add(BOMB) and sub_weapons.count(BOMB) == 0
	sub_weapons.own(BOMB)
	for i in SubWeapons.CARRY_LIMIT:
		valid = valid and sub_weapons.add(BOMB)
	valid = valid and sub_weapons.count(BOMB) == 9
	return valid and not sub_weapons.add(BOMB) and sub_weapons.count(BOMB) == 9


func _test_spend() -> bool:
	var sub_weapons := SubWeapons.new()
	sub_weapons.own(BOMB)
	var valid := not sub_weapons.spend(BOMB)
	sub_weapons.add(BOMB)
	valid = valid and sub_weapons.spend(BOMB) and sub_weapons.count(BOMB) == 0
	return valid and not sub_weapons.spend(BOMB)


# Unknown kinds are dropped, the one held is owned, and counts are held to the limit.
func _test_starts_from_run() -> bool:
	var carried := SubWeapons.new(BOMB, [&"nothing"], {BOMB: 12, &"nothing": 3})
	var valid := carried.held == BOMB and carried.owned == [BOMB] and carried.count(BOMB) == 9
	valid = valid and carried.to_counts() == {BOMB: 9}
	var unknown := SubWeapons.new(&"nothing", [], {})
	return valid and unknown.held == &"" and unknown.owned.is_empty()
