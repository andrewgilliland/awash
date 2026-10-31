extends RefCounted

const Equipment := preload("res://scripts/items/equipment.gd")
const TUNIC := &"worn_leather_tunic"
const SHORT_SWORD := &"short_sword"


func get_tests() -> Array:
	return [
		["A new Run wears the Worn Leather Tunic", _test_starts_in_tunic],
		["The Worn Leather Tunic gives no Defense", _test_tunic_has_no_defense],
		["Defense takes its value off a hit", _test_defense_takes_off_hit],
		["A hit always costs at least 5", _test_hit_costs_at_least_five],
		["Defense never makes a weak hit cost more", _test_weak_hit_not_raised],
		["A new Run owns only the Worn Leather Tunic", _test_owns_tunic],
		["Taking Armor off leaves no Defense", _test_take_off],
		["Only owned Armor can be worn", _test_wear_owned_only],
		["Equipment starts from what the Run carried", _test_starts_from_run],
		["Unknown Armor is neither owned nor worn", _test_unknown_armor_dropped],
		["Every Armor has an icon", _test_every_armor_has_icon],
		["A new Run holds the Short Sword, its only Weapon", _test_holds_short_sword],
		["Every Weapon has an icon", _test_every_weapon_has_icon],
		["The Defense with any Armor, or none, can be read", _test_defense_with],
	]


func _test_starts_in_tunic() -> bool:
	var equipment := Equipment.new()
	return Equipment.STARTING_ARMOR == TUNIC and equipment.armor == TUNIC


func _test_tunic_has_no_defense() -> bool:
	var equipment := Equipment.new(TUNIC)
	var valid := equipment.armor_name() == "Worn Leather Tunic" and equipment.defense() == 0
	return valid and equipment.hit_cost(10) == 10 and equipment.hit_cost(15) == 15


func _test_defense_takes_off_hit() -> bool:
	return Equipment.cost_after_defense(10, 5) == 5 and Equipment.cost_after_defense(15, 5) == 10


func _test_hit_costs_at_least_five() -> bool:
	return (
		Equipment.MIN_HIT == 5
		and Equipment.cost_after_defense(10, 10) == 5
		and Equipment.cost_after_defense(15, 40) == 5
	)


func _test_weak_hit_not_raised() -> bool:
	return Equipment.cost_after_defense(3, 0) == 3 and Equipment.cost_after_defense(3, 5) == 3


func _test_owns_tunic() -> bool:
	return Equipment.new().owned == [TUNIC]


func _test_take_off() -> bool:
	var equipment := Equipment.new()
	equipment.take_off()
	return (
		equipment.armor == &""
		and equipment.defense() == 0
		and equipment.armor_name() == "None"
		and equipment.hit_cost(10) == 10
		and equipment.owned == [TUNIC]
	)


func _test_wear_owned_only() -> bool:
	var equipment := Equipment.new()
	equipment.take_off()
	var valid := not equipment.wear(&"nothing") and equipment.armor == &""
	return valid and equipment.wear(TUNIC) and equipment.armor == TUNIC


# Nothing worn is kept; whatever is worn is owned.
func _test_starts_from_run() -> bool:
	var bare := Equipment.new(&"", [TUNIC])
	var valid := bare.armor == &"" and bare.owned == [TUNIC]
	var worn := Equipment.new(TUNIC, [])
	return valid and worn.armor == TUNIC and worn.owned == [TUNIC]


func _test_unknown_armor_dropped() -> bool:
	var equipment := Equipment.new(&"nothing", [&"nothing", TUNIC])
	return equipment.armor == &"" and equipment.owned == [TUNIC]


func _test_every_armor_has_icon() -> bool:
	var valid := true
	for id in Equipment.ARMOR:
		var icon: String = Equipment.ARMOR[id].get("icon", "")
		valid = valid and ResourceLoader.exists(icon)
	return valid


func _test_holds_short_sword() -> bool:
	var equipment := Equipment.new()
	return (
		Equipment.STARTING_WEAPON == SHORT_SWORD
		and equipment.weapon == SHORT_SWORD
		and equipment.weapon_name() == "Short Sword"
		and equipment.owned_weapons == [SHORT_SWORD]
	)


func _test_every_weapon_has_icon() -> bool:
	var valid := not Equipment.WEAPONS.is_empty()
	for id in Equipment.WEAPONS:
		var icon: String = Equipment.WEAPONS[id].get("icon", "")
		valid = valid and ResourceLoader.exists(icon)
	return valid


func _test_defense_with() -> bool:
	var equipment := Equipment.new()
	return equipment.defense_with(TUNIC) == 0 and equipment.defense_with(&"") == 0
