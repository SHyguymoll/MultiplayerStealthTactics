class_name HUDRadialMenu
extends Node2D

const TWEEN_TIME = 0.2

var button_icons := {
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
	twe.tween_property($UL, "position", Vector2(-272, -272), TWEEN_TIME)
	twe.tween_property($U, "position", Vector2(-68, -331), TWEEN_TIME)
	twe.tween_property($UR, "position", Vector2(136, -272), TWEEN_TIME)
	twe.tween_property($L, "position", Vector2(-331, -68), TWEEN_TIME)
	twe.tween_property($R, "position", Vector2(195, -68), TWEEN_TIME)
	twe.tween_property($DL, "position", Vector2(-272, 136), TWEEN_TIME)
	twe.tween_property($D, "position", Vector2(-68, 195), TWEEN_TIME)
	twe.tween_property($DR, "position", Vector2(136, 136), TWEEN_TIME)

func button_collapse_animation():
	var middle = Vector2(-68, -68)
	var twe := create_tween()
	twe.set_parallel(true)
	twe.set_trans(Tween.TRANS_CUBIC)
	twe.tween_property($UL, "position", middle, TWEEN_TIME)
	twe.tween_property($U, "position", middle, TWEEN_TIME)
	twe.tween_property($UR, "position", middle, TWEEN_TIME)
	twe.tween_property($L, "position", middle, TWEEN_TIME)
	twe.tween_property($R, "position", middle, TWEEN_TIME)
	twe.tween_property($DL, "position", middle, TWEEN_TIME)
	twe.tween_property($D, "position", middle, TWEEN_TIME)
	twe.tween_property($DR, "position", middle, TWEEN_TIME)


func _ready() -> void:
	button_spread_animation()


func button_menu_screen(choice : String):
	match choice:
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
		"top":
			pass


func _button_pressed_metadata(button_texture : Texture2D):
	if button_texture == button_icons.none:
		return
	print(button_texture)


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
