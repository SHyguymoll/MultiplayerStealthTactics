class_name HUDRadialMenu
extends Node2D

signal decision_made(decision_array : Array)
signal movement_decision_made(decision_array : Array)
signal aiming_decision_made(decision_array : Array)

const TWEEN_TIME = 0.2
const ICON_DIST = 32
const DIST_CIRCLE_ADD = 40

const ICONS := {
	none = preload("res://assets/sprites/radial_menu/none.png"),
	cancel_back = preload("res://assets/sprites/radial_menu/cancel.png"),
	halt = preload("res://assets/sprites/radial_menu/halt.png"),
	look = preload("res://assets/sprites/radial_menu/look.png"),
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
var current_screen : String

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
	var mid = _m.size.x/-2
	_disable_all_buttons()
	visible = true
	var twe := create_tween()
	twe.set_parallel(true)
	twe.set_trans(Tween.TRANS_CUBIC)
	twe.tween_property(_ul, "position", Vector2(mid - ICON_DIST*3, mid - ICON_DIST*3), TWEEN_TIME)
	twe.tween_property(_u, "position", Vector2(mid, mid - ICON_DIST*3 - DIST_CIRCLE_ADD), TWEEN_TIME)
	twe.tween_property(_ur, "position", Vector2(mid + ICON_DIST*3, mid - ICON_DIST*3), TWEEN_TIME)
	twe.tween_property(_l, "position", Vector2(mid - ICON_DIST*3 - DIST_CIRCLE_ADD, mid), TWEEN_TIME)
	_m.position = Vector2(mid, mid)
	twe.tween_property(_r, "position", Vector2(mid + ICON_DIST*3 + DIST_CIRCLE_ADD, mid), TWEEN_TIME)
	twe.tween_property(_dl, "position", Vector2(mid - ICON_DIST*3, mid + ICON_DIST*3), TWEEN_TIME)
	twe.tween_property(_d, "position", Vector2(mid, mid + ICON_DIST*3 + DIST_CIRCLE_ADD), TWEEN_TIME)
	twe.tween_property(_dr, "position", Vector2(mid + ICON_DIST*3, mid + ICON_DIST*3), TWEEN_TIME)
	twe.finished.connect(_enable_all_buttons)

func button_collapse_animation(instant := false):
	_disable_all_buttons()
	var middle = _m.size/-2
	if instant:
		_ul.position = middle
		_u.position = middle
		_ur.position = middle
		_l.position = middle
		_r.position = middle
		_dl.position = middle
		_d.position = middle
		_dr.position = middle
		visible = false
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
	twe.finished.connect(func(): visible = false)

func _enable_all_buttons():
	_ul.disabled = false
	_u.disabled = false
	_ur.disabled = false
	_l.disabled = false
	_m.disabled = false
	_r.disabled = false
	_dl.disabled = false
	_d.disabled = false
	_dr.disabled = false

func _disable_all_buttons():
	_ul.disabled = true
	_u.disabled = true
	_ur.disabled = true
	_l.disabled = true
	_m.disabled = true
	_r.disabled = true
	_dl.disabled = true
	_d.disabled = true
	_dr.disabled = true


func debug_agent():
	referenced_agent = Agent.new()
	referenced_agent.state = Agent.States.CRAWL
	referenced_agent.held_items = ["cigar", "analyzer", "box"]
	referenced_agent.held_weapons = [GameWeapon.new(), GameWeapon.new()]
	referenced_agent.held_weapons[0].icon = GameIcons.WEP.rifle
	referenced_agent.held_weapons[0].type = GameWeapon.Types.BIG
	referenced_agent.held_weapons[1].icon = GameIcons.WEP.noise_maker
	referenced_agent.held_weapons[1].type = GameWeapon.Types.THROWN
	referenced_agent.held_weapons[1].reserve_ammo = 5


#func _ready() -> void:
	#debug_agent()
	#init_menu()

func init_menu():
	button_collapse_animation(true)
	current_screen = "top"
	button_menu_screen()

func determine_items():
	_ul.icon = ICONS.none
	_u.icon = ICONS.none
	_ur.icon = ICONS.none
	var candidates := referenced_agent.held_items.duplicate()
	if referenced_agent.selected_item > -1:
		candidates.remove_at(referenced_agent.selected_item)
		candidates.insert(referenced_agent.selected_item, GameIcons.ITM.none)
	if len(candidates) > 0:
		_ul.icon = GameIcons.ITM[candidates[0]]
	if len(candidates) > 1:
		_u.icon = GameIcons.ITM[candidates[1]]
	if len(candidates) > 2:
		_ur.icon = GameIcons.ITM[candidates[2]]


func determine_weapons():
	_ul.icon = ICONS.none
	_ur.icon = ICONS.none
	var candidates : Array[GameWeapon] = referenced_agent.held_weapons.duplicate()
	if referenced_agent.selected_weapon > -1:
		candidates.remove_at(referenced_agent.selected_weapon)
		candidates.insert(referenced_agent.selected_weapon, GameIcons.WEP.fist)
	if len(candidates) > 0:
		_ul.icon = candidates[0].icon
	if len(candidates) > 1:
		_ur.icon = candidates[1].icon


func button_menu_screen():
	match current_screen:
		"top":
			if referenced_agent.in_standing_state():
				_ul.icon = ICONS.stance_crouch
				_u.icon = ICONS.run
				if referenced_agent.state == referenced_agent.States.RUN:
					_u.icon = ICONS.halt
				_ur.icon = ICONS.walk
				if referenced_agent.state == referenced_agent.States.WALK:
					_ur.icon = ICONS.halt
				if referenced_agent.can_prone():
					_l.icon = ICONS.stance_prone
				else:
					_l.icon = ICONS.none
				#_l.icon = ICONS.stance_prone
				_m.icon = ICONS.cancel_back
				_r.icon = ICONS.use_weapon
				_dl.icon = ICONS.look
				_d.icon = ICONS.swap_item
				_dr.icon = ICONS.swap_weapon
			if referenced_agent.in_crouching_state():
				if referenced_agent.can_stand():
					_ul.icon = ICONS.stance_stand
				else:
					_ul.icon = ICONS.none
				#_ul.icon = ICONS.stance_stand
				_u.icon = ICONS.none
				_ur.icon = ICONS.crouch_walk
				if referenced_agent.state == referenced_agent.States.CROUCH_WALK:
					_ur.icon = ICONS.halt
				if referenced_agent.can_prone():
					_l.icon = ICONS.stance_prone
				else:
					_l.icon = ICONS.none
				#_l.icon = ICONS.stance_prone
				_m.icon = ICONS.cancel_back
				_r.icon = ICONS.use_weapon
				_dl.icon = ICONS.look
				_d.icon = ICONS.swap_item
				_dr.icon = ICONS.swap_weapon
			if referenced_agent.in_prone_state():
				if referenced_agent.can_stand():
					_ul.icon = ICONS.stance_stand
				else:
					_ul.icon = ICONS.none
				#_ul.icon = ICONS.stance_stand
				_u.icon = ICONS.none
				_ur.icon = ICONS.crawl
				if referenced_agent.state == referenced_agent.States.CRAWL:
					_ur.icon = ICONS.halt
				if referenced_agent.can_crouch():
					_l.icon = ICONS.stance_crouch
				else:
					_l.icon = ICONS.none
				#_l.icon = ICONS.stance_crouch
				_m.icon = ICONS.cancel_back
				_r.icon = ICONS.none
				_dl.icon = ICONS.look
				_d.icon = ICONS.swap_item
				_dr.icon = ICONS.swap_weapon
		"swap_item":
			determine_items()
			_l.icon = ICONS.none
			_m.icon = ICONS.cancel_back
			_r.icon = ICONS.none
			_dl.icon = ICONS.none
			_d.icon = ICONS.none
			_dr.icon = ICONS.none
		"swap_weapon":
			determine_weapons()
			_u.icon = ICONS.none
			_l.icon = ICONS.none
			_m.icon = ICONS.cancel_back
			_r.icon = ICONS.none
			_dl.icon = ICONS.none
			_d.icon = ICONS.none
			_dr.icon = ICONS.none
	_ul.visible = _ul.icon != ICONS.none
	_u.visible = _u.icon != ICONS.none
	_ur.visible = _ur.icon != ICONS.none
	_l.visible = _l.icon != ICONS.none
	_m.visible = _m.icon != ICONS.none
	_r.visible = _r.icon != ICONS.none
	_dl.visible = _dl.icon != ICONS.none
	_d.visible = _d.icon != ICONS.none
	_dr.visible = _dr.icon != ICONS.none
	button_collapse_animation(true)
	button_spread_animation()


func _button_pressed_metadata(button_texture : Texture2D):
	match button_texture:
		ICONS.none:
			button_collapse_animation()
		ICONS.cancel_back:
			if current_screen in ["swap_item", "swap_weapon"]:
				current_screen = "top"
				button_menu_screen()
				button_collapse_animation(true)
				button_spread_animation()
			else:
				button_collapse_animation()
		ICONS.swap_item:
			current_screen = "swap_item"
			button_menu_screen()
		ICONS.swap_weapon:
			current_screen = "swap_weapon"
			button_menu_screen()
		ICONS.stance_stand:
			decision_made.emit([referenced_agent, Agent.GameActions.GO_STAND])
			button_collapse_animation()
		ICONS.stance_crouch:
			decision_made.emit([referenced_agent, Agent.GameActions.GO_CROUCH])
			button_collapse_animation()
		ICONS.stance_prone:
			decision_made.emit([referenced_agent, Agent.GameActions.GO_PRONE])
			button_collapse_animation()
		ICONS.run:
			movement_decision_made.emit([referenced_agent, Agent.GameActions.RUN_TO_POS])
			button_collapse_animation()
		ICONS.walk:
			movement_decision_made.emit([referenced_agent, Agent.GameActions.WALK_TO_POS])
			button_collapse_animation()
		ICONS.crouch_walk:
			movement_decision_made.emit([referenced_agent, Agent.GameActions.CROUCH_WALK_TO_POS])
			button_collapse_animation()
		ICONS.crawl:
			movement_decision_made.emit([referenced_agent, Agent.GameActions.CRAWL_TO_POS])
			button_collapse_animation()
		ICONS.use_weapon:
			aiming_decision_made.emit([referenced_agent, Agent.GameActions.USE_WEAPON])
			button_collapse_animation()
	if button_texture in GameIcons.WEP:
		var wep_in_question = GameIcons.WEP.find_key(button_texture)
		decision_made.emit([referenced_agent.name, Agent.GameActions.CHANGE_WEAPON, wep_in_question])
		button_collapse_animation()
	if button_texture in GameIcons.ITM:
		var itm_in_question = GameIcons.ITM.find_key(button_texture)
		decision_made.emit([referenced_agent.name, Agent.GameActions.CHANGE_ITEM, itm_in_question])
		button_collapse_animation()


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