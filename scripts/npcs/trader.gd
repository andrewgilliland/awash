extends "res://scripts/npcs/villager.gd"

# Tidefen's TRADER, who keeps the Supply Shop at the market stall: talking to them opens the
# Shop instead of a conversation.

const SHOP_GROUP := &"shop_panel"
const DIALOGUE_BOX_GROUP := &"dialogue_box"


func _on_interacted(by: Node) -> void:
	_face(by)
	var box := get_tree().get_first_node_in_group(DIALOGUE_BOX_GROUP)
	if box != null and box.call("is_open"):
		return
	var shop := get_tree().get_first_node_in_group(SHOP_GROUP)
	if shop != null and not shop.call("is_open"):
		shop.call("open")
