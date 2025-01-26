@tool
class_name SpawnPoint
extends Node3D

const SERVER_SPAWN_ICON = preload("res://assets/sprites/game_popups/debug_agspawn_server.png")
const CLIENT_SPAWN_ICON = preload("res://assets/sprites/game_popups/debug_agspawn_client.png")

@onready var debug_icon : Sprite3D = $DebugIcon

@export var server_true_client_false : bool

func get_spawn_point():
	return ($RayCast3D as RayCast3D).get_collision_point() + global_position

func _ready():
	debug_icon.texture = SERVER_SPAWN_ICON if server_true_client_false else CLIENT_SPAWN_ICON

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		debug_icon.texture = SERVER_SPAWN_ICON if server_true_client_false else CLIENT_SPAWN_ICON
