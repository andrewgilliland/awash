extends RefCounted

# The Supply Shop's stock: what Tidefen's TRADER sells, in the order the Shop lists it, as
# [Supply kind, price in Gold].

const Supplies := preload("res://scripts/items/supplies.gd")

const STOCK := [
	[Supplies.MEAT_PIE, 15],
	[Supplies.BRINECAP, 8],
]
