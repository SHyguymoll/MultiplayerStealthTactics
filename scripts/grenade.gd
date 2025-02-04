class_name Grenade
extends CharacterBody3D

@onready var _explosion_hitbox : Area3D = $ExplosionHitbox

@export var server_knows : bool
@export var client_knows : bool

@export var boom_time : int
@export var explode := false

var start_position : Vector3
var landing_position : Vector3

var player_id : int
var wep_id : String

func _ready() -> void:
	start_position = global_position
	boom_time = 30
	get_node(wep_id).visible = true


func should_be_visible():
	if server_knows and multiplayer.is_server():
		return true
	if client_knows and not multiplayer.is_server():
		return true
	return false


func _tick() -> void:
	visible = should_be_visible()
	boom_time = boom_time - 1
	global_position = start_position.lerp(landing_position, clamp(float(30 - boom_time)/30.0, 0.0, 1.0))
	if boom_time == -100:
		explode = true


func explosion_afflicted() -> Array:
	return _explosion_hitbox.get_overlapping_areas()
