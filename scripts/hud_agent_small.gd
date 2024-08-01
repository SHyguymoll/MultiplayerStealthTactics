class_name HUDAgentSmall
extends Control

const REMAIN_DIV = 3
const DELTA_DIV = 0.85

@onready var _label : Label = $Textures/Label
@onready var _state_tex : TextureRect = $Textures/AgentState
@onready var _wep_tex : TextureRect = $Textures/Equipped/Weapon
@onready var _itm_tex : TextureRect = $Textures/Equipped/Item
@onready var _wep_in_bar : ProgressBar = $WeaponAmmoIn
@onready var _wep_res_bar : ProgressBar = $WeaponAmmoReserve
@onready var _health_bar : ProgressBar = $Textures/Health
@onready var _stun_health_bar : ProgressBar = $Textures/StunHealth

var ref_ag : Agent

var _wep_in_mod_dir = 1
var _wep_res_mod_dir = 1

var flash := 0.0

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


func _physics_process(delta: float) -> void:
	flash = lerpf(flash, 0.0, 0.2)
	$Textures/AgentState/Flash.color = Color(1, 1, 1, flash)
	if ref_ag == null:
		return
	match ref_ag.state:
		Agent.States.STAND, Agent.States.CROUCH, Agent.States.PRONE:
			_state_tex.texture = GameRefs.STE.active
		Agent.States.HURT, Agent.States.GRABBED:
			_state_tex.texture = GameRefs.STE.alert
		Agent.States.STUNNED:
			_state_tex.texture = GameRefs.STE.stunned
		Agent.States.DEAD:
			_state_tex.texture = GameRefs.STE.dead
	if ref_ag.state != Agent.States.DEAD and len(ref_ag.held_weapons) > 0:
		_wep_tex.texture = GameRefs.return_icon(ref_ag, true)
	if ref_ag.state != Agent.States.DEAD and len(ref_ag.held_items) > 0:
		_itm_tex.texture = GameRefs.return_icon(ref_ag, false)

	_label.text = GameRefs.extract_agent_name(ref_ag.name)
	_health_bar.value = ref_ag.health
	_stun_health_bar.value = ref_ag.stun_health
	if ref_ag.state == Agent.States.DEAD:
		return
	if ref_ag.selected_weapon == -1:
		return
	_wep_in_bar.max_value = GameRefs.get_weapon_attribute(GameRefs.get_weapon_node(ref_ag.held_weapons[ref_ag.selected_weapon]), "ammo")
	_wep_in_bar.value = GameRefs.get_weapon_node(ref_ag.held_weapons[ref_ag.selected_weapon]).loaded_ammo
	_wep_res_bar.max_value = GameRefs.get_weapon_attribute(GameRefs.get_weapon_node(ref_ag.held_weapons[ref_ag.selected_weapon]), "ammo") * 3
	_wep_res_bar.value = GameRefs.get_weapon_node(ref_ag.held_weapons[ref_ag.selected_weapon]).reserve_ammo
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

