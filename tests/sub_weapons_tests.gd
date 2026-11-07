extends RefCounted

const SubWeapons := preload("res://scripts/items/sub_weapons.gd")
const BOMB := &"bomb"
# Where a Bomb's body is drawn, below its fuse: on its icon and its lit frames, and painted on the
# bomb crate's side.
const BOMB_BODIES := {
	"res://assets/items/bomb.png": Rect2i(0, 2, 8, 6),
	"res://assets/items/bomb_lit.png": Rect2i(0, 2, 16, 6),
	"res://assets/world/bomb_crate.png": Rect2i(14, 23, 4, 4),
}
# Dark iron is grey: no more colour in it than this. A pixel darker than black's limit shows no
# colour at all, whatever its tint.
const IRON_SATURATION := 0.3
const BLACK_VALUE := 0.2


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
		["A Bomb is drawn in dark iron, not brown clay", _test_bomb_dark],
	]


func _test_bomb_dark() -> bool:
	var valid := true
	for path: String in BOMB_BODIES:
		var image := (load(path) as Texture2D).get_image()
		image.decompress()
		var body: Rect2i = BOMB_BODIES[path]
		var drawn := 0
		for y in range(body.position.y, body.end.y):
			for x in range(body.position.x, body.end.x):
				var pixel := image.get_pixel(x, y)
				if pixel.a == 0.0:
					continue
				drawn += 1
				if pixel.v >= BLACK_VALUE and pixel.s > IRON_SATURATION:
					push_error("%s is coloured at (%d, %d): %s" % [path, x, y, pixel.to_html()])
					valid = false
		valid = valid and drawn > 0
	return valid


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
