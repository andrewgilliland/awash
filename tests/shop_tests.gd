extends RefCounted

# The Supply Shop: Tidefen's TRADER sells Meat Pies and Brinecaps for Gold. Buying one spends its
# price and carries one more, only with the Gold and the room for it.

const SHOP_PATH := "res://scripts/items/shop.gd"
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const Supplies := preload("res://scripts/items/supplies.gd")

# Needs a root that is already in the tree: the Player reads the Run in _ready.
var _root: Window


func _init(root: Window) -> void:
	_root = root


func get_tests() -> Array:
	return [
		["The Shop sells Meat Pies for 15 Gold and Brinecaps for 8", _test_stock],
		["Buying spends the price and carries one more, and the Run keeps both", _test_buys],
		["Nothing is bought without the Gold, or past the carry limit", _test_cannot_buy],
	]


func _test_stock() -> bool:
	if not ResourceLoader.exists(SHOP_PATH):
		return false
	var shop: GDScript = load(SHOP_PATH)
	var stock: Array = shop.get("STOCK")
	return stock == [[Supplies.MEAT_PIE, 15], [Supplies.BRINECAP, 8]]


func _test_buys() -> bool:
	var player := _player(20)
	var run := _root.get_node("RunState")
	var valid: bool = player.call("can_buy", Supplies.MEAT_PIE, 15)
	valid = valid and player.call("buy_supply", Supplies.MEAT_PIE, 15)
	valid = valid and player.get("gold") == 5
	valid = valid and player.get("supplies").count(Supplies.MEAT_PIE) == 1
	valid = valid and run.get("player_gold") == 5
	valid = valid and run.get("player_supplies").get(Supplies.MEAT_PIE) == 1
	_close(player)
	return valid


func _test_cannot_buy() -> bool:
	var player := _player(10)
	var valid: bool = not player.call("can_buy", Supplies.MEAT_PIE, 15)
	valid = valid and not player.call("buy_supply", Supplies.MEAT_PIE, 15)
	valid = valid and player.get("gold") == 10
	for i in Supplies.CARRY_LIMIT:
		player.get("supplies").add(Supplies.BRINECAP)
	valid = valid and not player.call("can_buy", Supplies.BRINECAP, 8)
	valid = valid and not player.call("buy_supply", Supplies.BRINECAP, 8)
	valid = valid and player.get("gold") == 10
	_close(player)
	return valid


func _player(gold: int) -> Node:
	_root.get_node("RunState").call("start_run")
	var player := PLAYER_SCENE.instantiate()
	_root.add_child(player)
	player.call("gain_gold", gold)
	return player


func _close(player: Node) -> void:
	player.free()
	_root.get_node("RunState").call("start_run")
