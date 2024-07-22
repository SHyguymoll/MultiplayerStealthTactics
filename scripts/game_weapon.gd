class_name GameWeapon
extends Node

@export var reserve_ammo : int = 0
@export var loaded_ammo : int = 0
@export var wep_name : String # Refer to GameRefs.WEP for valid string names
@export var wep_id : String # set when loading game for unique weapons


func _init(weapon_name : String, weapon_id : String) -> void:
	wep_name = weapon_name
	wep_id = weapon_id
	loaded_ammo = GameRefs.WEP[wep_name].ammo
	reserve_ammo = loaded_ammo * 3


func reload_weapon() -> bool:
	if GameRefs.WEP[wep_name].ammo <= reserve_ammo:
		loaded_ammo = GameRefs.WEP[wep_name].ammo
		reserve_ammo -= GameRefs.WEP[wep_name].ammo
		return true
	elif reserve_ammo > 0:
		loaded_ammo = reserve_ammo
		reserve_ammo = 0
		return true
	else:
		return false

func has_ammo() -> bool:
	return loaded_ammo + reserve_ammo > 0
