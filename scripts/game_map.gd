class_name GameMap
extends Node3D

# spawns must comfortably support 4 agents
# spawn entry format is [position, rotation]
@export var server_agent_spawns = [
	[Vector2.ZERO, 0],
	[Vector2.ZERO, 0],
	[Vector2.ZERO, 0],
	[Vector2.ZERO, 0],
]
@export var client_agent_spawns = [
	[Vector2.ZERO, 0],
	[Vector2.ZERO, 0],
	[Vector2.ZERO, 0],
	[Vector2.ZERO, 0],
]

enum Objectives {
	CAPTURE_ENEMY_FLAG,
	CAPTURE_CENTRAL_FLAG,
	TARGET_DEFEND,
}
@export var objective : GameObjective

@export var server_exfiltrate_zone : Area3D
@export var client_exfiltrate_zone : Area3D

func _ready() -> void:
	server_exfiltrate_zone.area_entered.connect(_server_agent_entered_exfil)
	server_exfiltrate_zone.area_exited.connect(_server_agent_exited_exfil)
	client_exfiltrate_zone.area_entered.connect(_client_agent_entered_exfil)
	client_exfiltrate_zone.area_exited.connect(_client_agent_exited_exfil)


func _server_agent_entered_exfil(agent_area : Area3D):
	var agent : Agent = agent_area.get_parent()

func _server_agent_exited_exfil(agent_area : Area3D):
	var agent : Agent = agent_area.get_parent()

func _client_agent_entered_exfil(agent_area : Area3D):
	var agent : Agent = agent_area.get_parent()

func _client_agent_exited_exfil(agent_area : Area3D):
	var agent : Agent = agent_area.get_parent()
