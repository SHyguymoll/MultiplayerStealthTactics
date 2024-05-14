class_name GameMap
extends Node3D

# spawns must comfortably support 4 agents
# agents will be spawned at node3d position (but made flush with floor) with node3d y rotation
@export var ag_spwn_serv_1 : Node3D
@export var ag_spwn_serv_2 : Node3D
@export var ag_spwn_serv_3 : Node3D
@export var ag_spwn_serv_4 : Node3D
@export var ag_spwn_clie_1 : Node3D
@export var ag_spwn_clie_2 : Node3D
@export var ag_spwn_clie_3 : Node3D
@export var ag_spwn_clie_4 : Node3D

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
