class_name HUDRadialMenu
extends Node2D

const TWEEN_TIME = 0.2

const ICONS := {
	none = preload("res://assets/sprites/radial_menu/none.png"),
	cancel_back = preload("res://assets/sprites/radial_menu/cancel.png"),
	stance_stand = preload("res://assets/sprites/radial_menu/stand.png"),
	run = preload("res://assets/sprites/radial_menu/run.png"),
	walk = preload("res://assets/sprites/radial_menu/walk.png"),
	stance_crouch = preload("res://assets/sprites/radial_menu/crouch.png"),
	crouch_walk = preload("res://assets/sprites/radial_menu/crouch_walk.png"),
	stance_prone = preload("res://assets/sprites/radial_menu/prone.png"),
	crawl = preload("res://assets/sprites/radial_menu/crawl.png"),
	swap_item = preload("res://assets/sprites/radial_menu/swap_item.png"),
	swap_weapon = preload("res://assets/sprites/radial_menu/swap_weapon.png"),
	use_weapon = preload("res://assets/sprites/radial_menu/use_weapon.png"),
}

var referenced_agent : Agent

@onready var _ul : Button = $UL
@onready var _u : Button = $U
@onready var _ur : Button = $UR
@onready var _l : Button = $L
@onready var _m : Button = $M
@onready var _r : Button = $R
@onready var _dl : Button = $DL
@onready var _d : Button = $D
@onready var _dr : Button = $DR

func button_spread_animation():
	var twe := create_tween()
	twe.set_parallel(true)
	twe.set_trans(Tween.TRANS_CUBIC)
	twe.tween_property(_ul, "position", Vector2(-272, -272), TWEEN_TIME)
	twe.tween_property(_u, "position", Vector2(-68, -331), TWEEN_TIME)
	twe.tween_property(_ur, "position", Vector2(136, -272), TWEEN_TIME)
	twe.tween_property(_l, "position", Vector2(-331, -68), TWEEN_TIME)
	twe.tween_property(_r, "position", Vector2(195, -68), TWEEN_TIME)
	twe.tween_property(_dl, "position", Vector2(-272, 136), TWEEN_TIME)
	twe.tween_property(_d, "position", Vector2(-68, 195), TWEEN_TIME)
	twe.tween_property(_dr, "position", Vector2(136, 136), TWEEN_TIME)

func button_collapse_animation(instant := false):
	var middle = Vector2(-68, -68)
	if instant:
		_ul.position = middle
		_u.position = middle
		_ur.position = middle
		_l.position = middle
		_r.position = middle
		_dl.position = middle
		_d.position = middle
		_dr.position = middle
		return
	var twe := create_tween()
	twe.set_parallel(true)
	twe.set_trans(Tween.TRANS_CUBIC)
	twe.tween_property(_ul, "position", middle, TWEEN_TIME)
	twe.tween_property(_u, "position", middle, TWEEN_TIME)
	twe.tween_property(_ur, "position", middle, TWEEN_TIME)
	twe.tween_property(_l, "position", middle, TWEEN_TIME)
	twe.tween_property(_r, "position", middle, TWEEN_TIME)
	twe.tween_property(_dl, "position", middle, TWEEN_TIME)
	twe.tween_property(_d, "position", middle, TWEEN_TIME)
	twe.tween_property(_dr, "position", middle, TWEEN_TIME)


func _ready() -> void:
	button_spread_animation()


func button_menu_screen(choice : String):
	match choice:
		"top":
			if referenced_agent.in_standing_state():
				_ul.icon = ICONS.stance_crouch
				_u.icon = ICONS.run
				_ur.icon = ICONS.walk
				_l.icon = ICONS.stance_prone
				_m.icon = ICONS.cancel_back
				_r.icon = ICONS.use_weapon
				_dl.icon = ICONS.none
				_d.icon = ICONS.swap_item
				_dr.icon = ICONS.swap_weapon
			if referenced_agent.in_crouching_state():
				_ul.icon = ICONS.stance_stand
				_u.icon = ICONS.none
				_ur.icon = ICONS.crouch_walk
				_l.icon = ICONS.stance_prone
				_m.icon = ICONS.cancel_back
				_r.icon = ICONS.use_weapon
				_dl.icon = ICONS.none
				_d.icon = ICONS.swap_item
				_dr.icon = ICONS.swap_weapon
			if referenced_agent.in_prone_state():
				_ul.icon = ICONS.stance_stand
				_u.icon = ICONS.none
				_ur.icon = ICONS.crawl
				_l.icon = ICONS.stance_crouch
				_m.icon = ICONS.cancel_back
				_r.icon = ICONS.none
				_dl.icon = ICONS.none
				_d.icon = ICONS.swap_item
				_dr.icon = ICONS.swap_weapon
		"top":
			pass
		"top":
			pass
		"top":
			pass
		"top":
			pass
		"top":
			pass


func _button_pressed_metadata(button_texture : Texture2D):
	print(button_texture)
	match button_texture:
		ICONS.none:
			return
		ICONS.cancel_back:
			pass
		ICONS.stance_stand:
			pass
		ICONS.run:
			pass
		ICONS.walk:
			pass
		ICONS.stance_crouch:
			pass
		ICONS.crouch_walk:
			pass
		ICONS.stance_prone:
			pass
		ICONS.crawl:
			pass
		ICONS.swap_item:
			pass
		ICONS.swap_weapon:
			pass
		ICONS.use_weapon:
			pass
	if button_texture in HUDAgentSmall.WEAPON:
		pass
	if button_texture in HUDAgentSmall.ITEM:
		pass


func _on_ul_pressed() -> void:
	_button_pressed_metadata(_ul.icon)


func _on_u_pressed() -> void:
	_button_pressed_metadata(_u.icon)


func _on_ur_pressed() -> void:
	_button_pressed_metadata(_ur.icon)


func _on_l_pressed() -> void:
	_button_pressed_metadata(_l.icon)


func _on_m_pressed() -> void:
	_button_pressed_metadata(_m.icon)


func _on_r_pressed() -> void:
	_button_pressed_metadata(_r.icon)


func _on_dl_pressed() -> void:
	_button_pressed_metadata(_dl.icon)


func _on_d_pressed() -> void:
	_button_pressed_metadata(_d.icon)


func _on_dr_pressed() -> void:
	_button_pressed_metadata(_dr.icon)
