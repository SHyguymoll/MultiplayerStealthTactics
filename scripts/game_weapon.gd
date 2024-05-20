class_name GameWeapon
extends Node

enum Types {
	SMALL,
	BIG,
	THROWN,
	PLACED,
}
var reserve_ammo : int
var ammo_capacity : int
var loaded_ammo : int = 0
var reload_time : int
var type : Types
var icon : Texture2D

func _ready():
	reload_weapon()

func reload_weapon() -> bool:
	if ammo_capacity <= reserve_ammo:
		loaded_ammo = ammo_capacity
		reserve_ammo -= ammo_capacity
		return true
	elif reserve_ammo > 0:
		loaded_ammo = reserve_ammo
		reserve_ammo = 0
		return true
	else:
		return false

func weapon_subroutine() -> void:
	loaded_ammo -= 1
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
