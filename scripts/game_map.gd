class_name GameMap
extends Node3D

# spawns must comfortably support 4 agents
# agents will be spawned at node3d position (but made flush with floor) with node3d y rotation
@export var agent_spawn_server_1 : Node3D
@export var agent_spawn_server_2 : Node3D
@export var agent_spawn_server_3 : Node3D
@export var agent_spawn_server_4 : Node3D
@export var agent_spawn_client_1 : Node3D
@export var agent_spawn_client_2 : Node3D
@export var agent_spawn_client_3 : Node3D
@export var agent_spawn_client_4 : Node3D

enum Objectives {
	CAPTURE_ENEMY_FLAG,
	CAPTURE_CENTRAL_FLAG,
	TARGET_DEFEND,
}
@export var objective : Objectives
@export var objective_params : Array

@export var server_exfiltrate_zone : Area3D
@export var client_exfiltrate_zone : Area3D

func _ready():
	for spawn in $Spawns.get_children() as Array[Sprite3D]:
		spawn.get_child(0).visible = false
