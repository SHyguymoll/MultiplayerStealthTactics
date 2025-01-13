class_name WeaponPickup
extends Node3D

@export var attached_wep : String
var position_y_inter = 0
var position_y = 0
@export var server_knows = false
@export var client_knows = false
var agent_collecting : Agent = null
var generate_weapon : bool = false

var _outline_mat_base = preload("res://assets/models/materials/agent_outline.tres")
var _outline_mat_flag = preload("res://assets/models/materials/map_element_outline.tres")
var _outline_mat : StandardMaterial3D
var base_color : Color

func _ready():
	if name.begins_with("map_"):
		_outline_mat = _outline_mat_flag.duplicate()
	else:
		_outline_mat = _outline_mat_base.duplicate()
	base_color = _outline_mat.albedo_color
	for weapon_mesh in get_children():
		if not weapon_mesh is MeshInstance3D:
			continue
		weapon_mesh.set_surface_override_material(1, _outline_mat)
		weapon_mesh.visible = false
	visible = multiplayer.is_server() and server_knows or not multiplayer.is_server() and client_knows or name.begins_with("map_")


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
	_outline_mat.albedo_color = _outline_mat.albedo_color.lerp(base_color, 0.2)


func flash_weapon():
	_outline_mat.albedo_color = Color.PURPLE


func _animate(delta: float) -> void:
	position_y_inter = fmod(position_y_inter + delta*2, PI*2)
	position_y = sin(position_y_inter)/16 + 0.5
	for weapon_mesh in get_children():
		if not weapon_mesh is MeshInstance3D:
			continue
		weapon_mesh.rotation.y += delta * 3
		weapon_mesh.position.y = position_y
