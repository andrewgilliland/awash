extends RefCounted

# What each moment of a fight does to the screen: the one place its hit-stop and shake are set.
# Callers say what happened; this decides how it feels.

const HitStop := preload("res://scripts/combat/hit_stop.gd")
const CameraShake := preload("res://scripts/combat/camera_shake.gd")

# Frames play freezes for: a blow that lands, and a heavier one (a defeat, or the Player hurt).
const HIT_FRAMES := 3
const HEAVY_FRAMES := 5
const PLAYER_HURT_SHAKE := [2, 0.15]
const BOMB_BURST_SHAKE := [3, 0.25]
const SLAM_SHAKE := [3, 0.3]
const WALL_CRUMBLE_SHAKE := [2, 0.3]


# A blow landed on an enemy: it flashes white, and play freezes, longer if it was the last.
static func enemy_struck(enemy: Node, defeated: bool) -> void:
	var flash := enemy.get_node_or_null(^"HitFlash")
	if flash != null:
		flash.call("flash")
	HitStop.request(enemy, HEAVY_FRAMES if defeated else HIT_FRAMES)


static func player_hurt(player: Node) -> void:
	HitStop.request(player, HEAVY_FRAMES)
	CameraShake.request(player, PLAYER_HURT_SHAKE[0], PLAYER_HURT_SHAKE[1])


static func bomb_burst(bomb: Node) -> void:
	CameraShake.request(bomb, BOMB_BURST_SHAKE[0], BOMB_BURST_SHAKE[1])


static func slam(warden: Node) -> void:
	CameraShake.request(warden, SLAM_SHAKE[0], SLAM_SHAKE[1])


static func wall_crumble(wall: Node) -> void:
	CameraShake.request(wall, WALL_CRUMBLE_SHAKE[0], WALL_CRUMBLE_SHAKE[1])
