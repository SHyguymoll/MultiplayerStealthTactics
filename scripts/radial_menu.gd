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
	no_action = preload("res://assets/sprites/radial_menu/no_action.png"),
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
	drop_weapon = preload("res://assets/sprites/radial_menu/drop_weapon.png"),
	menu_weapon = preload("res://assets/sprites/radial_menu/menu_weapon.png"),
	pick_up_weapon = preload("res://assets/sprites/radial_menu/pick_up_weapon.png"),
	use_weapon = preload("res://assets/sprites/radial_menu/use_weapon.png"),
	reload_weapon = preload("res://assets/sprites/radial_menu/reload_weapon.png"),
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
	referenced_agent.held_weapons = [GameWeapon.new("rifle", "debug_rifle"), GameWeapon.new("noise_maker", "debug_noise_maker")]


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
		candidates.insert(referenced_agent.selected_item, GameRefs.ITM.none.icon)
	if len(candidates) > 0:
		_ul.icon = GameRefs.ITM[candidates[0]].icon
	if len(candidates) > 1:
		_u.icon = GameRefs.ITM[candidates[1]].icon
	if len(candidates) > 2:
		_ur.icon = GameRefs.ITM[candidates[2]].icon


func determine_weapons():
	_u.icon = ICONS.none
	_dl.icon = ICONS.none
	_dr.icon = ICONS.none
	var candidates : Array[GameWeapon] = referenced_agent.held_weapons.duplicate()
	if current_screen == "swap_weapon":
		_u.icon = GameRefs.WEP[candidates[0].wep_name].icon
		if len(candidates) > 1 and candidates[1].has_ammo():
			_dl.icon = GameRefs.WEP[candidates[1].wep_name].icon
		if len(candidates) > 2 and candidates[2].has_ammo():
			_dr.icon = GameRefs.WEP[candidates[2].wep_name].icon
	else:
		if len(candidates) > 1:
			_dl.icon = GameRefs.WEP[candidates[1].wep_name].icon
		if len(candidates) > 2:
			_dr.icon = GameRefs.WEP[candidates[2].wep_name].icon
	match referenced_agent.selected_weapon:
		0:
			_u.icon = ICONS.none
		1:
			_dl.icon = ICONS.none
		2:
			_dr.icon = ICONS.none


# the action is available unless it was already selected,
# in which case a no action button replaces the action.
func a_o_na(icon, action : Agent.GameActions):
	if len(referenced_agent.queued_action) == 0:
		return icon
	if referenced_agent.queued_action[0] != action:
		return icon
	else:
		return ICONS.no_action


func button_menu_screen():
	match current_screen:
		"top":
			var buttons = [
				a_o_na(ICONS.stance_crouch, Agent.GameActions.GO_CROUCH), #0: ul
				a_o_na(ICONS.run, Agent.GameActions.RUN_TO_POS), #1: u
				a_o_na(ICONS.walk, Agent.GameActions.WALK_TO_POS), #2: ur
				a_o_na(ICONS.stance_prone, Agent.GameActions.GO_PRONE), #3: l
				ICONS.cancel_back, #4: m (shouldn't ever change, here for consistency)
				a_o_na(ICONS.use_weapon, Agent.GameActions.USE_WEAPON), #5: r
				a_o_na(ICONS.look, Agent.GameActions.LOOK_AROUND), #6: dl
				a_o_na(ICONS.swap_item, Agent.GameActions.CHANGE_ITEM), #7: d
				ICONS.menu_weapon, #8: dr
			]

			if referenced_agent.in_standing_state():
				if not referenced_agent.can_prone():
					buttons[3] = ICONS.none
				if referenced_agent.state == referenced_agent.States.RUN:
					buttons[1] = ICONS.halt
				if referenced_agent.state == referenced_agent.States.WALK:
					buttons[2] = ICONS.halt

			elif referenced_agent.in_crouching_state():
				buttons[0] = a_o_na(ICONS.stance_stand, Agent.GameActions.GO_STAND)
				if not referenced_agent.can_stand():
					buttons[0] = ICONS.none
				buttons[1] = ICONS.none
				buttons[2] = a_o_na(ICONS.crouch_walk, Agent.GameActions.CROUCH_WALK_TO_POS)
				if referenced_agent.state == referenced_agent.States.CROUCH_WALK:
					buttons[2] = ICONS.halt
				if not referenced_agent.can_prone():
					buttons[3] = ICONS.none
				if GameRefs.compare_wep_type(referenced_agent, GameRefs.WeaponTypes.CQC):
					buttons[5] = ICONS.none

			elif referenced_agent.in_prone_state():
				buttons[0] = a_o_na(ICONS.stance_stand, Agent.GameActions.GO_STAND)
				if not referenced_agent.can_stand():
					buttons[0] = ICONS.none
				buttons[1] = ICONS.none
				buttons[2] = a_o_na(ICONS.crawl, Agent.GameActions.CRAWL_TO_POS)
				if referenced_agent.state == referenced_agent.States.CRAWL:
					buttons[2] = ICONS.halt
				buttons[3] = a_o_na(ICONS.stance_crouch, Agent.GameActions.GO_CROUCH)
				if not referenced_agent.can_crouch():
					buttons[3] = ICONS.none
				buttons[5] = ICONS.none

			if not GameRefs.compare_wep_type(referenced_agent, GameRefs.WeaponTypes.CQC):
				if referenced_agent.held_weapons[
						referenced_agent.selected_weapon].loaded_ammo == 0:
					buttons[5] = ICONS.reload_weapon

			_ul.icon = buttons[0]
			_u.icon = buttons[1]
			_ur.icon = buttons[2]
			_l.icon = buttons[3]
			_m.icon = buttons[4]
			_r.icon = buttons[5]
			_dl.icon = buttons[6]
			_d.icon = buttons[7]
			_dr.icon = buttons[8]
		"swap_item":
			determine_items()
			_l.icon = ICONS.none
			_m.icon = ICONS.cancel_back
			_r.icon = ICONS.none
			_dl.icon = ICONS.none
			_d.icon = ICONS.none
			_dr.icon = ICONS.none
		"menu_weapon":
			_ul.icon = a_o_na(ICONS.drop_weapon, Agent.GameActions.DROP_WEAPON)
			_u.icon = a_o_na(ICONS.swap_weapon, Agent.GameActions.CHANGE_WEAPON)
			_ur.icon = a_o_na(ICONS.pick_up_weapon, Agent.GameActions.PICK_UP_WEAPON)
			_l.icon = ICONS.none
			_m.icon = ICONS.cancel_back
			_r.icon = ICONS.none
			_dl.icon = ICONS.none
			_d.icon = ICONS.none
			_dr.icon = ICONS.none
		"swap_weapon", "drop_weapon":
			determine_weapons()
			_ul.icon = ICONS.none
			_ur.icon = ICONS.none
			_l.icon = ICONS.none
			_m.icon = ICONS.cancel_back
			_r.icon = ICONS.none
			_d.icon = ICONS.none
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


func _button_pressed_metadata(button : Button):
	var button_texture = button.icon
	match button_texture:
		ICONS.none:
			button_collapse_animation()
		ICONS.cancel_back:
			if current_screen in ["swap_item", "menu_weapon"]:
				current_screen = "top"
				button_menu_screen()
				button_collapse_animation(true)
				button_spread_animation()
			elif current_screen in ["swap_weapon", "drop_weapon", "pick_up_weapon"]:
				current_screen = "menu_weapon"
				button_menu_screen()
				button_collapse_animation(true)
				button_spread_animation()
			else:
				button_collapse_animation()
		ICONS.swap_item:
			current_screen = "swap_item"
			button_menu_screen()
		ICONS.menu_weapon:
			current_screen = "menu_weapon"
			button_menu_screen()
		ICONS.swap_weapon:
			current_screen = "swap_weapon"
			button_menu_screen()
		ICONS.drop_weapon:
			current_screen = "drop_weapon"
			button_menu_screen()
		ICONS.pick_up_weapon:
			current_screen = "pick_up_weapon"
			button_menu_screen()
		ICONS.no_action, ICONS.halt:
			decision_made.emit([null])
			button_collapse_animation()
		ICONS.stance_stand:
			decision_made.emit([Agent.GameActions.GO_STAND])
			button_collapse_animation()
		ICONS.stance_crouch:
			decision_made.emit([Agent.GameActions.GO_CROUCH])
			button_collapse_animation()
		ICONS.stance_prone:
			decision_made.emit([Agent.GameActions.GO_PRONE])
			button_collapse_animation()
		ICONS.run:
			movement_decision_made.emit([Agent.GameActions.RUN_TO_POS])
			button_collapse_animation()
		ICONS.walk:
			movement_decision_made.emit([Agent.GameActions.WALK_TO_POS])
			button_collapse_animation()
		ICONS.crouch_walk:
			movement_decision_made.emit([Agent.GameActions.CROUCH_WALK_TO_POS])
			button_collapse_animation()
		ICONS.crawl:
			movement_decision_made.emit([Agent.GameActions.CRAWL_TO_POS])
			button_collapse_animation()
		ICONS.use_weapon:
			aiming_decision_made.emit([Agent.GameActions.USE_WEAPON])
			button_collapse_animation()
		ICONS.reload_weapon:
			decision_made.emit([Agent.GameActions.RELOAD_WEAPON])
			button_collapse_animation()
		ICONS.look:
			aiming_decision_made.emit([Agent.GameActions.LOOK_AROUND])
			button_collapse_animation()
	for possible in GameRefs.ITM:
		if button_texture == GameRefs.ITM[possible].icon:
			decision_made.emit([Agent.GameActions.CHANGE_ITEM, possible])
			button_collapse_animation()
	for possible in GameRefs.WEP:
		if button_texture == GameRefs.WEP[possible].icon:
			if current_screen != "pick_up_weapon":
				var new_ind = 0
				for ag_possible in referenced_agent.held_weapons:
					if button_texture == GameRefs.WEP[ag_possible.wep_name].icon:
						match current_screen:
							"swap_weapon":
								decision_made.emit([Agent.GameActions.CHANGE_WEAPON, new_ind])
							"drop_weapon":
								decision_made.emit([Agent.GameActions.DROP_WEAPON, new_ind])
						button_collapse_animation()
						return
					new_ind += 1
			else:
				pass #TODO: for weapon around agent, needs method


func _on_ul_pressed() -> void:
	_button_pressed_metadata(_ul)


func _on_u_pressed() -> void:
	_button_pressed_metadata(_u)


func _on_ur_pressed() -> void:
	_button_pressed_metadata(_ur)


func _on_l_pressed() -> void:
	_button_pressed_metadata(_l)


func _on_m_pressed() -> void:
	_button_pressed_metadata(_m)


func _on_r_pressed() -> void:
	_button_pressed_metadata(_r)


func _on_dl_pressed() -> void:
	_button_pressed_metadata(_dl)


func _on_d_pressed() -> void:
	_button_pressed_metadata(_d)


func _on_dr_pressed() -> void:
	_button_pressed_metadata(_dr)
