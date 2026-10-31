extends "res://scripts/combat/hitbox.gd"

# Rubble the Reefback's chest-beat brings down: a shadow marks the floor, then a rock falls on
# it, harming the Player only as it lands, and is gone.

const FALL_DELAY := 1.0
const FALL_TIME := 0.4
# How high above the mark the rock starts, and how long it lies there, striking, once it lands.
const FALL_HEIGHT := 140.0
const IMPACT_TIME := 0.12
const MARK_BLINK := 0.12

var _time: float = 0.0

@onready var _mark: CanvasItem = $Mark
@onready var _rock: Node2D = $Rock


func _ready() -> void:
	super._ready()
	damage = 10
	_rock.position.y = -FALL_HEIGHT


func _physics_process(delta: float) -> void:
	_time += delta
	var falling := clampf((_time - FALL_DELAY) / FALL_TIME, 0.0, 1.0)
	_rock.position.y = -FALL_HEIGHT * (1.0 - falling * falling)
	_mark.visible = falling < 1.0 and fmod(_time, MARK_BLINK * 2.0) < MARK_BLINK or falling == 0.0
	var landed_for := _time - FALL_DELAY - FALL_TIME
	var striking := landed_for >= 0.0 and landed_for < IMPACT_TIME
	if active != striking:
		active = striking
	if landed_for >= IMPACT_TIME:
		queue_free()
