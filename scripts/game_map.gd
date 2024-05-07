class_name GameMap
extends Node3D

signal server_agent_entered_exfil_zone(agent : Agent)
signal server_agent_exited_exfil_zone(agent : Agent)
signal client_agent_entered_exfil_zone(agent : Agent)
signal client_agent_exited_exfil_zone(agent : Agent)

# spawns must comfortably support 4 agents
@export var server_agent_spawns = {
	1:
		[Vector2.ZERO, 0],
	2:
		[Vector2.ZERO, 0],
	3:
		[Vector2.ZERO, 0],
	4:
		[Vector2.ZERO, 0],
}
@export var client_agent_spawns = {
	1:
		[Vector2.ZERO, 0],
	2:
		[Vector2.ZERO, 0],
	3:
		[Vector2.ZERO, 0],
	4:
		[Vector2.ZERO, 0],
}

enum Objectives {
	CAPTURE_ENEMY_FLAG,
	CAPTURE_CENTRAL_FLAG,
	TARGET_DEFEND,
}
@export var objective : GameObjective

@export var server_exfiltrate_zone : Area3D
@export var client_exfiltrate_zone : Area3D

func _ready() -> void:
	server_exfiltrate_zone
