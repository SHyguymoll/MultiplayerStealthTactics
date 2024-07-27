class_name WeaponPickup
extends Node3D

@export var attached_wep : String
var position_y_inter = 0
var position_y = 0
@export var server_knows = false
@export var client_knows = false
var agent_collecting : Agent = null
var generate_weapon : bool = false

func _ready():
	for weapon_mesh in get_children():
		if not weapon_mesh is MeshInstance3D:
			continue
		weapon_mesh.visible = false
	visible = multiplayer.is_server() and server_knows or not multiplayer.is_server() and client_knows


func _process(_d) -> void:
	if generate_weapon:
		if multiplayer.is_server():
			var wep_id = attached_wep.split("_", true, 1)[1]
			$"../..".weapon_spawner.spawn({
				wep_id = wep_id,
				wep_name = name,
				loaded_ammo = GameRefs.WEP[wep_id].ammo,
				reserve_ammo = GameRefs.WEP[wep_id].ammo * 3,
			})
			generate_weapon = false
		return
	if GameRefs.get_weapon_node(attached_wep) == null:
		return
	get_node(GameRefs.get_weapon_node(attached_wep).wep_id).visible = true


func _animate(delta: float) -> void:
	position_y_inter = fmod(position_y_inter + delta*2, PI*2)
	position_y = sin(position_y_inter)/16 + 0.5
	for weapon_mesh in get_children():
		if not weapon_mesh is MeshInstance3D:
			continue
		weapon_mesh.rotation.y += delta * 3
		weapon_mesh.position.y = position_y
