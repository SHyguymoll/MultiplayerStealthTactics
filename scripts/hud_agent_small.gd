class_name HUDAgentSmall
extends Control

const REMAIN_DIV = 3
const DELTA_DIV = 0.85

var state := {
	active = preload("res://assets/sprites/hud_agent_small/state/active.png"),
	alert = preload("res://assets/sprites/hud_agent_small/state/alert.png"),
	stunned = preload("res://assets/sprites/hud_agent_small/state/stunned.png"),
	asleep = preload("res://assets/sprites/hud_agent_small/state/asleep.png"),
	dead = preload("res://assets/sprites/hud_agent_small/state/dead.png"),
	unknown = preload("res://assets/sprites/hud_agent_small/state/unknown.png"),
}

var weapon := {
	fist = preload("res://assets/sprites/hud_agent_small/weapons/fist.png"),
	pistol = preload("res://assets/sprites/hud_agent_small/weapons/pistol.png"),
	rifle = preload("res://assets/sprites/hud_agent_small/weapons/rifle.png"),
	shotgun = preload("res://assets/sprites/hud_agent_small/weapons/shotgun.png"),
	grenade_smoke = preload("res://assets/sprites/hud_agent_small/weapons/grenade_smoke.png"),
	grenade_frag = preload("res://assets/sprites/hud_agent_small/weapons/grenade_frag.png"),
	noise_maker = preload("res://assets/sprites/hud_agent_small/weapons/noise_maker.png"),
	middle_flag = preload("res://assets/sprites/hud_agent_small/weapons/flag.png"),
	enemy_flag = preload("res://assets/sprites/hud_agent_small/weapons/flag.png"),
}

var item := {
	none = preload("res://assets/sprites/hud_agent_small/items/none.png"),
	body_armor = preload("res://assets/sprites/hud_agent_small/items/body_armor.png"),
	fake_death = preload("res://assets/sprites/hud_agent_small/items/fake_death_pill.png"),
	box = preload("res://assets/sprites/hud_agent_small/items/box.png"),
	cigar = preload("res://assets/sprites/hud_agent_small/items/cigar.png"),
	reflex_enhancer = preload("res://assets/sprites/hud_agent_small/items/reflex_pill.png"),
	analyzer = preload("res://assets/sprites/hud_agent_small/items/analyzer.png"),
}

@onready var _wep_in_bar : ProgressBar = $WeaponAmmoIn
@onready var _wep_res_bar : ProgressBar = $WeaponAmmoReserve
@onready var _item_in_bar : ProgressBar = $ItemAmmoIn
@onready var _item_res_bar : ProgressBar = $ItemAmmoReserve

var _wep_in_mod_dir = 1
var _wep_res_mod_dir = 1
var _item_in_mod_dir = 1
var _item_res_mod_dir = 1

func update_state(new_state):
	($Textures/AgentState as TextureRect).texture = state.get(new_state, state.unknown)


func update_weapon(new_weapon):
	($Textures/Equipped/Weapon as TextureRect).texture = weapon.get(new_weapon, weapon.fist)


func update_item(new_item):
	($Textures/Equipped/Item as TextureRect).texture = item.get(new_item, item.none)


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


func init_item_in(min_val, max_val, cur_val):
	_item_in_bar.min_value = min_val
	_item_in_bar.max_value = max_val
	_item_in_bar.value = cur_val


func update_item_in(new_val):
	_item_in_bar.value = new_val


func init_item_res(min_val, max_val, cur_val):
	_item_res_bar.min_value = min_val
	_item_res_bar.max_value = max_val
	_item_res_bar.value = cur_val


func update_item_res(new_val):
	_item_res_bar.value = new_val


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

	if _item_in_bar.value < _item_in_bar.max_value/REMAIN_DIV:
		_item_in_bar.modulate.s = clamp(_item_in_bar.modulate.s + (delta/DELTA_DIV * _item_in_mod_dir), 0.0, 1.0)
		if (_item_in_bar.modulate.s == 1.0 and _item_in_mod_dir == 1 or
				_item_in_bar.modulate.s == 0.0 and _item_in_mod_dir == -1):
			_item_in_mod_dir *= -1
			_item_in_bar.modulate.v = 1
	else:
		if _item_in_bar.modulate.s != 0.0:
			_item_in_bar.modulate.s = 0.0

	if _item_res_bar.value < _item_res_bar.max_value/REMAIN_DIV:
		_item_res_bar.modulate.s = clamp(_item_res_bar.modulate.s + (delta/DELTA_DIV * _item_res_mod_dir), 0.0, 1.0)
		if (_item_res_bar.modulate.s == 1.0 and _item_res_mod_dir == 1 or
				_item_res_bar.modulate.s == 0.0 and _item_res_mod_dir == -1):
			_item_res_mod_dir *= -1
			_item_res_bar.modulate.v = 1
	else:
		if _item_res_bar.modulate.s != 0.0:
			_item_res_bar.modulate.s = 0.0
