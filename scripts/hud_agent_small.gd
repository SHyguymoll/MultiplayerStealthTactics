class_name HUDAgentSmall
extends Control

const REMAIN_DIV = 3
const DELTA_DIV = 0.85

@onready var _state_tex : TextureRect = $Textures/AgentState
@onready var _wep_tex : TextureRect = $Textures/Equipped/Weapon
@onready var _itm_tex : TextureRect = $Textures/Equipped/Item
@onready var _wep_in_bar : ProgressBar = $WeaponAmmoIn
@onready var _wep_res_bar : ProgressBar = $WeaponAmmoReserve

var _wep_in_mod_dir = 1
var _wep_res_mod_dir = 1

func update_state(new_state):
	_state_tex.texture = GameIcons.STE.get(new_state, GameIcons.STE.unknown)


func update_weapon(new_weapon):
	_wep_tex.texture = GameIcons.WEP.get(new_weapon, GameIcons.WEP.fist)


func update_item(new_item):
	_itm_tex.texture = GameIcons.ITM.get(new_item, GameIcons.ITM.none)


func init_weapon_in(min_val, max_val, cur_val):
	_wep_in_bar.min_value = min_val
	_wep_in_bar.max_value = max_val
	_wep_in_bar.value = cur_val


func update_weapon_in(new_val):
	_wep_in_bar.value = new_val


func init_weapon_res(min_val, max_val, cur_val):
	_wep_res_bar.min_value = min_val
	_wep_res_bar.max_value = max_val
	_wep_res_bar.value = cur_val


func update_weapon_res(new_val):
	_wep_res_bar.value = new_val


func _process(delta: float) -> void:
	if _wep_in_bar.value < _wep_in_bar.max_value/REMAIN_DIV:
		_wep_in_bar.modulate.s = clamp(_wep_in_bar.modulate.s + (delta/DELTA_DIV * _wep_in_mod_dir), 0.0, 1.0)
		if (_wep_in_bar.modulate.s == 1.0 and _wep_in_mod_dir == 1 or
				_wep_in_bar.modulate.s == 0.0 and _wep_in_mod_dir == -1):
			_wep_in_mod_dir *= -1
			_wep_in_bar.modulate.v = 1
	else:
		if _wep_in_bar.modulate.s != 0.0:
			_wep_in_bar.modulate.s = 0.0

	if _wep_res_bar.value < _wep_res_bar.max_value/REMAIN_DIV:
		_wep_res_bar.modulate.s = clamp(_wep_res_bar.modulate.s + (delta/DELTA_DIV * _wep_res_mod_dir), 0.0, 1.0)
		if (_wep_res_bar.modulate.s == 1.0 and _wep_res_mod_dir == 1 or
				_wep_res_bar.modulate.s == 0.0 and _wep_res_mod_dir == -1):
			_wep_res_mod_dir *= -1
			_wep_res_bar.modulate.v = 1
	else:
		if _wep_res_bar.modulate.s != 0.0:
			_wep_res_bar.modulate.s = 0.0
