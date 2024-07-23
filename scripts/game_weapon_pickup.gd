class_name WeaponPickup
extends Node3D

@export var attached_wep : GameWeapon
var position_y_inter = 0
var position_y = 0
@export var server_knows = false
@export var client_knows = false
var agent_collecting : Agent = null

func _ready():
	for weapon_mesh in get_children():
		if not weapon_mesh is MeshInstance3D:
			continue
		weapon_mesh.visible = false
	match attached_wep.wep_name:
		"pistol":
			$Pistol.visible = true
		"rifle":
			$Rifle.visible = true
		"shotgun":
			$Shotgun.visible = true
		"grenade_smoke":
			$GrenadeSmoke.visible = true
		"grenade_frag":
			$GrenadeFrag.visible = true
		"grenade_noise":
			$GrenadeNoise.visible = true
		"noise_maker":
			$Pistol.visible = true
		"flag_center":
			$FlagCenter.visible = true
		"flag_server":
			$FlagServer.visible = true
		"flag_client":
			$FlagClient.visible = true
	visible = multiplayer.is_server() and server_knows or not multiplayer.is_server() and client_knows


func _animate(delta: float) -> void:
	position_y_inter = fmod(position_y_inter + delta*2, PI*2)
	position_y = sin(position_y_inter)/16 + 0.5
	for weapon_mesh in get_children():
		if not weapon_mesh is MeshInstance3D:
			continue
		weapon_mesh.rotation.y += delta * 3
		weapon_mesh.position.y = position_y
