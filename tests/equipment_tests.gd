extends RefCounted

const Equipment := preload("res://scripts/items/equipment.gd")
const TUNIC := &"worn_leather_tunic"


func get_tests() -> Array:
	return [
		["A new Run wears the Worn Leather Tunic", _test_starts_in_tunic],
		["The Worn Leather Tunic gives no Defense", _test_tunic_has_no_defense],
		["Defense takes its value off a hit", _test_defense_takes_off_hit],
		["A hit always costs at least 5", _test_hit_costs_at_least_five],
		["Defense never makes a weak hit cost more", _test_weak_hit_not_raised],
		["Unknown Armor falls back to the Worn Leather Tunic", _test_unknown_armor_falls_back],
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


func _test_unknown_armor_falls_back() -> bool:
	return Equipment.new(&"nothing").armor == TUNIC
