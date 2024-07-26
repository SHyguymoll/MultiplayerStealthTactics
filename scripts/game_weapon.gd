class_name GameWeapon
extends Node

@export var reserve_ammo : int = 0
@export var loaded_ammo : int = 0
@export var wep_id : String # Refer to GameRefs.WEP for valid string names

func reload_weapon() -> bool:
	if GameRefs.WEP[wep_id].ammo <= reserve_ammo:
		loaded_ammo = GameRefs.WEP[wep_id].ammo
		reserve_ammo -= GameRefs.WEP[wep_id].ammo
		return true
	elif reserve_ammo > 0:
		loaded_ammo = reserve_ammo
		reserve_ammo = 0
		return true
	else:
		return false


func has_ammo() -> bool:
	return loaded_ammo + reserve_ammo > 0


func is_map_element() -> bool:
	return name.begins_with("map_")
