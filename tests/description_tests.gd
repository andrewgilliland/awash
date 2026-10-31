extends RefCounted

const Equipment := preload("res://scripts/items/equipment.gd")
const Supplies := preload("res://scripts/items/supplies.gd")
# A description strip's line, in cells of the compact font, and how many lines it shows.
const LINE_CHARS := 35
const LINES := 2
const SWORD := "A plain blade Mara pulled from the sand."
const TUNIC := "Faded by salt. Light, but gives no Defense."
const BRINECAP := "A salt-crusted cave mushroom. Restores 10 Health."


func get_tests() -> Array:
	return [
		["Every Weapon and Armor has a description that fits", _test_equipment_described],
		["Every kind of Supply has a description that fits", _test_supplies_described],
	]


func _test_equipment_described() -> bool:
	var sword: Dictionary = Equipment.WEAPONS[Equipment.STARTING_WEAPON]
	var tunic: Dictionary = Equipment.ARMOR[Equipment.STARTING_ARMOR]
	var valid: bool = sword.get("description") == SWORD and tunic.get("description") == TUNIC
	for table: Dictionary in [Equipment.WEAPONS, Equipment.ARMOR]:
		for id in table:
			valid = valid and _fits(table[id].get("description", ""))
	return valid


func _test_supplies_described() -> bool:
	var brinecap: Dictionary = Supplies.KINDS[Supplies.BRINECAP]
	var valid: bool = brinecap.get("description") == BRINECAP
	for kind in Supplies.KINDS:
		valid = valid and _fits(Supplies.KINDS[kind].get("description", ""))
	return valid


# Whether the text is there and wraps, word by word, into the strip's lines.
func _fits(text: String) -> bool:
	if text.is_empty():
		return false
	var lines := 1
	var line := 0
	for word in text.split(" "):
		var needed := word.length() if line == 0 else line + 1 + word.length()
		if needed <= LINE_CHARS:
			line = needed
		else:
			lines += 1
			line = word.length()
	return lines <= LINES
