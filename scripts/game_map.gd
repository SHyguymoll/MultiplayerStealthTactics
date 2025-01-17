class_name GameMap
extends Node3D

# spawns must comfortably support 4 agents
# agents will be spawned at spawnpoint position (but made flush with floor via raycast) with y rotation
@export var agent_spawn_server_1 : SpawnPoint
@export var agent_spawn_server_2 : SpawnPoint
@export var agent_spawn_server_3 : SpawnPoint
@export var agent_spawn_server_4 : SpawnPoint
@export var agent_spawn_client_1 : SpawnPoint
@export var agent_spawn_client_2 : SpawnPoint
@export var agent_spawn_client_3 : SpawnPoint
@export var agent_spawn_client_4 : SpawnPoint

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
	for spawn in $Spawns.get_children() as Array[SpawnPoint]:
		spawn.debug_icon.visible = false
	$map_basic_nav.visible = false
	$map_basic.visible = true
