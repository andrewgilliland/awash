extends RefCounted

const Supplies := preload("res://scripts/items/supplies.gd")


func get_tests() -> Array:
	return [
		["Supplies start empty", _test_start_empty],
		["Every kind of Supply has a name and restores Health", _test_kinds_table],
		["Adding a Supply carries one more", _test_add_carries_more],
		["Supplies stop at the carry limit", _test_stop_at_limit],
		["Spending a Supply carries one fewer", _test_spend_carries_fewer],
		["Spending with none carried does nothing", _test_spend_none],
		["Supplies list the kinds carried", _test_kinds_carried],
		["Supplies can start from carried counts", _test_start_from_counts],
	]


func _test_start_empty() -> bool:
	var supplies := Supplies.new()
	return supplies.count(Supplies.BRINECAP) == 0 and supplies.kinds().is_empty()


func _test_kinds_table() -> bool:
	var brinecap: Dictionary = Supplies.KINDS.get(Supplies.BRINECAP, {})
	return brinecap.get("name") == "Brinecap" and brinecap.get("restores") == 10


func _test_add_carries_more() -> bool:
	var supplies := Supplies.new()
	var added := supplies.add(Supplies.BRINECAP)
	return added and supplies.count(Supplies.BRINECAP) == 1


func _test_stop_at_limit() -> bool:
	var supplies := Supplies.new()
	var valid := true
	for i in Supplies.CARRY_LIMIT:
		valid = valid and supplies.add(Supplies.BRINECAP)
	valid = valid and Supplies.CARRY_LIMIT == 9
	return (
		valid
		and not supplies.add(Supplies.BRINECAP)
		and supplies.count(Supplies.BRINECAP) == Supplies.CARRY_LIMIT
	)


func _test_spend_carries_fewer() -> bool:
	var supplies := Supplies.new()
	supplies.add(Supplies.BRINECAP)
	supplies.add(Supplies.BRINECAP)
	var spent := supplies.spend(Supplies.BRINECAP)
	return spent and supplies.count(Supplies.BRINECAP) == 1


func _test_spend_none() -> bool:
	var supplies := Supplies.new()
	return not supplies.spend(Supplies.BRINECAP) and supplies.count(Supplies.BRINECAP) == 0


func _test_kinds_carried() -> bool:
	var supplies := Supplies.new()
	supplies.add(Supplies.BRINECAP)
	var valid := supplies.kinds() == [Supplies.BRINECAP]
	supplies.spend(Supplies.BRINECAP)
	return valid and supplies.kinds().is_empty()


# The Run hands back what it carried; counts over the limit or of unknown kinds are dropped.
func _test_start_from_counts() -> bool:
	var supplies := Supplies.new({Supplies.BRINECAP: 3, &"nothing": 2})
	var valid := supplies.count(Supplies.BRINECAP) == 3 and supplies.count(&"nothing") == 0
	valid = valid and supplies.to_counts() == {Supplies.BRINECAP: 3}
	var over := Supplies.new({Supplies.BRINECAP: 40})
	return valid and over.count(Supplies.BRINECAP) == Supplies.CARRY_LIMIT
