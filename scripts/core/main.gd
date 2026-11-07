extends Node2D

const PAUSE_MENU_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const DIALOGUE_BOX_SCENE := preload("res://scenes/ui/dialogue_box.tscn")
const HEALTH_BAR_SCENE := preload("res://scenes/ui/health_bar.tscn")
const SUB_WEAPON_COUNT_SCENE := preload("res://scenes/ui/sub_weapon_count.tscn")
const GOLD_COUNT_SCENE := preload("res://scenes/ui/gold_count.tscn")
const SHOP_PANEL_SCENE := preload("res://scenes/ui/shop_panel.tscn")
const BOSS_BAR_SCENE := preload("res://scenes/ui/boss_bar.tscn")
# The scene each Supply or Weapon an enemy can leave where it fell lies as.
const Pickups := preload("res://scripts/items/pickups.gd")
# A Weapon lies this far to the right of the Supply left with it, so both show.
const WEAPON_BESIDE := Vector2(8.0, 0.0)
const RunStateScript := preload("res://scripts/core/run_state.gd")
const World := preload("res://scripts/core/world.gd")
const HitStop := preload("res://scripts/combat/hit_stop.gd")
const ENEMY_GROUP := &"enemy"
# Long enough to see the Player fall and hear the defeat sound before the Room is replaced.
const DEFEAT_PAUSE := 1.2

# Rolled once per enemy defeat, from 0 up to 1; under the enemy's DROP_CHANCE leaves its DROP,
# a Brinecap if it names none. An enemy with a WEAPON_DROP rolls again for it, under its
# WEAPON_DROP_CHANCE, until the Player owns it. Tests swap it for a fixed roll.
var drop_roll: Callable = randf
# Which Room this is, found in the World by its own scene; &"" when the World doesn't hold it.
var _room_id: StringName = &""
# Each Supply or Weapon defeated enemies left, as its scene and where, waiting for the Room's
# next physics step.
var _supplies_due: Array[Array] = []

@onready var _player: CharacterBody2D = $Player
@onready var _entries: Node = $Entries
@onready var _canvas_layer: CanvasLayer = $CanvasLayer


func _ready() -> void:
	_find_self_in_world()
	_fit_camera_to_room()
	_add_background()
	_ensure_pause_menu()
	_ensure_dialogue_box()
	_ensure_health_bar()
	_ensure_sub_weapon_count()
	_ensure_gold_count()
	_ensure_shop_panel()
	_ensure_boss_bar()
	_ensure_hit_stop()
	_place_player_at_entry()
	_play_region_music()
	if _player != null and not _player.is_connected(&"defeated", _on_player_defeated):
		_player.connect(&"defeated", _on_player_defeated)
	_hand_enemy_defeats_to_player()
	_save_run()


# Closing the window saves the Run too, as Quit to Desktop does.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_run()


# Entering a Room saves the Run, so CONTINUE picks up here.
func _save_run() -> void:
	var run := get_node_or_null("/root/RunState") if is_inside_tree() else null
	if run != null:
		run.call("save")


func _find_self_in_world() -> void:
	_room_id = World.room_for_scene(scene_file_path)
	if _room_id.is_empty():
		push_error("Scene '%s' is not a Room in the World." % scene_file_path)


# The camera stays inside the Room: its size in screens, from the World.
func _fit_camera_to_room() -> void:
	var camera := get_node_or_null("Player/Camera2D") as Camera2D
	if camera == null or _room_id.is_empty():
		return
	var room_size := Vector2(World.size(_room_id)) * World.SCREEN_SIZE
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(room_size.x)
	camera.limit_bottom = int(room_size.y)


# The Room's Background, from the World, drawn behind everything and told where the Room sits.
func _add_background() -> void:
	var path := World.background(_room_id)
	if path.is_empty() or has_node(^"Background"):
		return
	var background := (load(path) as PackedScene).instantiate()
	background.name = "Background"
	background.set("room_origin", Vector2(World.cell(_room_id)) * World.SCREEN_SIZE)
	add_child(background)
	move_child(background, 0)


# Every enemy defeated in this Room earns the Player its Experience and Gold, whatever struck it
# down, and may leave a Supply where it fell.
func _hand_enemy_defeats_to_player() -> void:
	if _player == null or not is_inside_tree():
		return
	for enemy in get_tree().get_nodes_in_group(ENEMY_GROUP):
		var hand_over := _on_enemy_defeated.bind(enemy)
		if is_ancestor_of(enemy) and not enemy.is_connected(&"defeated", hand_over):
			enemy.connect(&"defeated", hand_over)


func _on_enemy_defeated(experience: int, enemy: Node2D) -> void:
	_player.call("gain_experience", experience)
	var constants: Dictionary = enemy.get_script().get_script_constant_map()
	_player.call("gain_gold", constants.get("GOLD", 0))
	if drop_roll.call() < constants.get("DROP_CHANCE", 0.0):
		var supply: StringName = constants.get("DROP", &"brinecap")
		_supplies_due.append([Pickups.scene(supply), enemy.global_position])
	var weapon: StringName = constants.get("WEAPON_DROP", &"")
	if weapon.is_empty() or _player.get("equipment").owns_weapon(weapon):
		return
	if drop_roll.call() < constants.get("WEAPON_DROP_CHANCE", 0.0):
		_supplies_due.append([Pickups.scene(weapon), enemy.global_position + WEAPON_BESIDE])


# An enemy falls while physics is reporting the hit, when nothing may join the world, so its
# Supply or Weapon joins on the Room's next step.
func _physics_process(_delta: float) -> void:
	for due in _supplies_due:
		var supply := (due[0] as PackedScene).instantiate() as Node2D
		add_child(supply)
		supply.global_position = due[1]
	_supplies_due.clear()


# After a beat to see it fall, a defeated Player wakes at the Rest point last rung, or in the
# first Room before there is one, with full Health; the Run carries on.
func _on_player_defeated() -> void:
	await get_tree().create_timer(DEFEAT_PAUSE).timeout
	var run := _get_run()
	var wake_in := RunStateScript.FIRST_ROOM_ID
	if run != null:
		run.recover_from_defeat()
		wake_in = run.room_id
	get_tree().change_scene_to_file.call_deferred(World.scene(wake_in))


# The Run says which Entry the Player came through; this Room says where it is.
func _place_player_at_entry() -> void:
	var run := _get_run()
	var entry_id := run.entry_id if run != null else RunStateScript.DEFAULT_ENTRY_ID
	var entry := _entries.get_node_or_null(NodePath(entry_id)) as Marker2D
	if entry == null:
		push_error("Room '%s' has no Entry '%s'." % [_room_id, entry_id])
		return

	_player.global_position = entry.global_position


# Asks the Music autoload for this Room's region theme; the same theme plays on unbroken.
func _play_region_music() -> void:
	if not is_inside_tree():
		return
	var music := get_node_or_null("/root/Music")
	var theme := World.theme(_room_id)
	if music != null and not theme.is_empty():
		music.call("play", load(theme))


# Null outside the tree or without the autoload (headless tests), which reads as a new Run.
func _get_run() -> RunStateScript:
	if not is_inside_tree():
		return null

	return get_node_or_null("/root/RunState") as RunStateScript


func _ensure_pause_menu() -> void:
	if _canvas_layer == null:
		return

	if _canvas_layer.get_node_or_null("PauseMenu") != null:
		return

	var pause_menu := PAUSE_MENU_SCENE.instantiate()
	pause_menu.name = "PauseMenu"
	_canvas_layer.add_child(pause_menu)


# Freezes play a few frames as blows connect: the Room's own, so leaving it lets play go.
func _ensure_hit_stop() -> void:
	if get_node_or_null(^"HitStop") != null:
		return
	var stop := HitStop.new()
	stop.name = "HitStop"
	add_child(stop)


# The Health bar sits under the Pause menu and the dialogue box, so both draw over it.
func _ensure_health_bar() -> void:
	if _canvas_layer == null or _canvas_layer.get_node_or_null("HealthBar") != null:
		return
	var bar := HEALTH_BAR_SCENE.instantiate()
	bar.name = "HealthBar"
	_canvas_layer.add_child(bar)
	_canvas_layer.move_child(bar, 0)


# The Sub Weapon count sits under the Health bar, and under the Pause menu and dialogue box too.
func _ensure_sub_weapon_count() -> void:
	if _canvas_layer == null or _canvas_layer.get_node_or_null("SubWeaponCount") != null:
		return
	var count := SUB_WEAPON_COUNT_SCENE.instantiate()
	count.name = "SubWeaponCount"
	_canvas_layer.add_child(count)
	_canvas_layer.move_child(count, 0)


# The Gold count sits under the Sub Weapon count, and under the Pause menu and dialogue box too.
func _ensure_gold_count() -> void:
	if _canvas_layer == null or _canvas_layer.get_node_or_null("GoldCount") != null:
		return
	var count := GOLD_COUNT_SCENE.instantiate()
	count.name = "GoldCount"
	_canvas_layer.add_child(count)
	_canvas_layer.move_child(count, 0)


# The Supply Shop sits above everything, the Pause menu too, so it takes cancel and pause first
# while it is open.
func _ensure_shop_panel() -> void:
	if _canvas_layer == null or _canvas_layer.get_node_or_null("ShopPanel") != null:
		return
	var panel := SHOP_PANEL_SCENE.instantiate()
	panel.name = "ShopPanel"
	_canvas_layer.add_child(panel)


# The Boss Health bar sits under the Pause menu and the dialogue box too; it shows only while a
# Boss in the Room is fighting.
func _ensure_boss_bar() -> void:
	if _canvas_layer == null or _canvas_layer.get_node_or_null("BossBar") != null:
		return
	var bar := BOSS_BAR_SCENE.instantiate()
	bar.name = "BossBar"
	_canvas_layer.add_child(bar)
	_canvas_layer.move_child(bar, 0)


func _ensure_dialogue_box() -> void:
	if _canvas_layer == null or _canvas_layer.get_node_or_null("DialogueBox") != null:
		return
	var box := DIALOGUE_BOX_SCENE.instantiate()
	box.name = "DialogueBox"
	_canvas_layer.add_child(box)
