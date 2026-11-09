extends "res://scripts/npcs/villager.gd"

# A keeper of a Supply Shop, such as Tidefen's TRADER at the market stall: talking to them opens
# the Shop on the stock they keep instead of a conversation.

const Shop := preload("res://scripts/items/shop.gd")
const SHOP_GROUP := &"shop_panel"
const DIALOGUE_BOX_GROUP := &"dialogue_box"

# Which of the Shop's stocks they keep, by its name in scripts/items/shop.gd.
@export var stock_name: StringName = &"STOCK"


func _on_interacted(by: Node) -> void:
	_face(by)
	var box := get_tree().get_first_node_in_group(DIALOGUE_BOX_GROUP)
	if box != null and box.call("is_open"):
		return
	var shop := get_tree().get_first_node_in_group(SHOP_GROUP)
	if shop != null and not shop.call("is_open"):
		shop.call("open", Shop.stock(stock_name))
