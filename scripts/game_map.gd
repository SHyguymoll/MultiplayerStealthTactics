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

@export var world_graphics : Node3D
@export var world_collision : StaticBody3D
@export var crouch_gates : StaticBody3D
@export var prone_gates : StaticBody3D
@export var pointable_areas : StaticBody3D
@export var navigation : NavigationRegion3D

func _ready():
	agent_spawn_client_1.visible = false
	agent_spawn_client_2.visible = false
	agent_spawn_client_3.visible = false
	agent_spawn_client_4.visible = false
	agent_spawn_server_1.visible = false
	agent_spawn_server_2.visible = false
	agent_spawn_server_3.visible = false
	agent_spawn_server_4.visible = false

	world_graphics.visible = true
	world_collision.visible = false
	crouch_gates.visible = false
	prone_gates.visible = false
	pointable_areas.visible = false
	navigation.visible = false
