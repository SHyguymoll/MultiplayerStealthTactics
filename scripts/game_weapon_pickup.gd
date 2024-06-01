class_name WeaponPickup
extends Node3D

var attached_wep : GameWeapon
var position_y_inter = 0
var position_y = 0


func _ready():
	for weapon_mesh in get_children():
		if not weapon_mesh is MeshInstance3D:
			continue
		visible = false
	match attached_wep.wep_name:
		"pistol":
			$Pistol.visible = true
		"rifle":
			$Rifle.visible = true
		"shotgun":
			$Shotgun.visible = true
		"grenade_smoke":
			$Pistol.visible = true
		"grenade_frag":
			$Pistol.visible = true
		"noise_maker":
			$Pistol.visible = true
		"middle_flag":
			$Pistol.visible = true
		"enemy_flag":
			$Pistol.visible = true


func _physics_process(delta: float) -> void:
	position_y_inter = fmod(position_y_inter + delta*2, PI*2)
	position_y = sin(position_y_inter)/16 + 0.5
	for weapon_mesh in get_children():
		if not weapon_mesh is MeshInstance3D:
			continue
		weapon_mesh.rotation.y += delta * 3
		weapon_mesh.position.y = position_y
