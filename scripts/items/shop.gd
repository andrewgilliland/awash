extends RefCounted

# The Supply Shops' stock: what each keeper sells, in the order the Shop lists it, as
# [Supply kind, price in Gold]. A keeper names the stock they keep.

const Supplies := preload("res://scripts/items/supplies.gd")

# Tidefen's TRADER's.
const STOCK := [
	[Supplies.MEAT_PIE, 15],
	[Supplies.BRINECAP, 8],
]
# The Shrinekeeper Camp's keeper's, deeper in: Mourning Salts too.
const CAMP_STOCK := [
	[Supplies.MEAT_PIE, 15],
	[Supplies.BRINECAP, 8],
	[Supplies.MOURNING_SALT, 30],
]


# The stock a keeper keeps, by its name here; Tidefen's for a name it doesn't have.
static func stock(stock_name: StringName) -> Array:
	var shop: GDScript = load("res://scripts/items/shop.gd")
	return shop.get_script_constant_map().get(stock_name, STOCK)
