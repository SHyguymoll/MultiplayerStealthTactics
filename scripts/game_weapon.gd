class_name GameWeapon
extends Node

var reserve_ammo : int = 0
var loaded_ammo : int = 0
var reload_time : int
var cooldown_time : int
var wep_name : String # Refer to GameRefs.WEP for valid string names
var wep_id : String # set when loading game for unique weapons


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

func weapon_subroutine() -> void:
	loaded_ammo -= 1
	match GameRefs.WEP[wep_name].type:
		GameRefs.WeaponTypes.CQC:
			pass
		GameRefs.WeaponTypes.SMALL, GameRefs.WeaponTypes.BIG:
			pass
		GameRefs.WeaponTypes.THROWN:
			pass
		GameRefs.WeaponTypes.PLACED:
			pass

func use_weapon() -> bool:
	if loaded_ammo == 0:
		if reload_weapon():
			weapon_subroutine()
			return true
		else:
			return false
	else:
		weapon_subroutine()
		return true
