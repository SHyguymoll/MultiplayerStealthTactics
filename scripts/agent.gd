class_name Agent
extends CharacterBody3D

signal agent_selected(agent : Agent)

const CQC_START = Vector3(0, 0, 0.48)
const CQC_END = Vector3(0.545, 0, 0)
const GENERAL_LERP_VAL = 0.2

var view_dist : float = 2.5 #length of vision "cone" (really a pyramid)
var view_across : float = 1 #size of vision pyramid base
var eye_strength : float = 0.15 #multiplier applied to vision pyramid in relation to view target distance

var hearing_dist : float = 1.5 #distance of furthest possibly heard audio event

var movement_dist : float = 7.0 #distance of furthest possible movement
var movement_speed : float = 2.75 #movement speed when running (divided by 2 for walking, 2.5 for prone)

var player_id : int

@export var visible_level : int = 50 #bounded from 0 to 100, based on current state

@export var held_items : Array = [] #max length should be 3, only uses Strings
@export var held_weapons : Array = [] #max length should be 3 (including fist), also only uses Strings

@export var selected_item : int = -1 #index for item (-1 for no item)
@export var selected_weapon : int = 0 #index for weapon (0 for fist)

@export var percieved_by_friendly := false #determines if hud is updated

@export var skin_texture : String

@onready var _vision_cone : Sprite3D = $AgentVision
const VIS_CONE_BASE = Vector2(0.405, 0.98)

@onready var _anim : AnimationTree = $AnimationTree
@onready var _anim_state : AnimationNodeStateMachinePlayback = _anim.get("parameters/playback")
@onready var _mesh : MeshInstance3D = $Agent/game_rig/Skeleton3D/Mesh
@onready var _custom_skin_mat : StandardMaterial3D
var _outline_mat_base = preload("res://assets/models/materials/agent_outline.tres")
var _outline_mat : StandardMaterial3D
@onready var _eyes : Area3D = $Eyes
@onready var _eye_cone : ConvexPolygonShape3D = $Eyes/CollisionShape3D.shape
@onready var _ears : Area3D = $Ears
@onready var _body : Area3D = $Body
@onready var _ear_cylinder : CylinderShape3D = _ears.get_node("CollisionShape3D").shape
@onready var _world_collide : CollisionShape3D = $WorldCollision
@onready var _prone_ray : RayCast3D = $ProneCheck
@onready var _crouch_ray : RayCast3D = $CrouchCheck
@onready var _stand_ray : RayCast3D = $StandCheck
@onready var _cqc_anim_helper : Node3D = $CQCAnimationHelper
@onready var _nav_agent : NavigationAgent3D = $NavigationAgent3D
@onready var _active_item_icon : Sprite3D = $ActiveItem
@onready var _pickup_range : Area3D = $PickupRange
@onready var _held_weapon_meshes = {
	pistol = $Agent/game_rig/Skeleton3D/Pistol,
	rifle = $Agent/game_rig/Skeleton3D/Rifle,
	shotgun = $Agent/game_rig/Skeleton3D/Shotgun,
	grenade_frag = $Agent/game_rig/Skeleton3D/GrenadeFrag,
	grenade_smoke = $Agent/game_rig/Skeleton3D/GrenadeSmoke,
	grenade_noise = $Agent/game_rig/Skeleton3D/GrenadeNoise,
	flag_center = $Agent/game_rig/Skeleton3D/FlagCenter,
	flag_server = $Agent/game_rig/Skeleton3D/FlagServer,
	flag_client = $Agent/game_rig/Skeleton3D/FlagClient,
}

@onready var sounds = {
	glanced = ($ClientsideSoundEffects/GlancedSomething as AudioStreamPlayer3D),
	spotted_element = ($ClientsideSoundEffects/SpottedElement as AudioStreamPlayer3D),
	spotted_agent = ($ClientsideSoundEffects/SpottedAgent as AudioStreamPlayer3D),
}

# Actions are stored as an enum in order to make serialization much easier
# each agent will be stored in the action timeline as an array, where the first entry is the action,
# and any important metadata (position, rotation, selection, etc.) follows.
enum GameActions {
	GO_STAND, GO_CROUCH, GO_PRONE,
	RUN_TO_POS, WALK_TO_POS, CROUCH_WALK_TO_POS, CRAWL_TO_POS,
	LOOK_AROUND,
	CHANGE_ITEM, CHANGE_WEAPON,
	PICK_UP_WEAPON, DROP_WEAPON,
	USE_WEAPON, RELOAD_WEAPON,
	HALT,
}
#format is [GameActions, ... (game action parameters)]
@export var queued_action = []
var action_text := ""
enum ActionDoneness {
	NOT_DONE,
	SUCCESS,
	FAIL,
}
@export var action_done : ActionDoneness

enum States {
	STAND, CROUCH, PRONE,
	RUN, WALK, CROUCH_WALK, CRAWL,
	USING_ITEM, USING_WEAPON, CQC_GRAB, FIRE_GUN, THROW_BOMB, RELOADING_WEAPON,
	HURT, GRABBED, STUNNED, DEAD,
	EXFILTRATED,
}
@export var state : States = States.STAND

@export var target_direction : float
@export var stun_time : int = 0
@export var health : int = 10
@export var stun_health : int = 10
@export var target_visible_level : int = 50
@export var target_accuracy : float
@export var weapons_animation_blend := Vector2.ONE
@export var target_world_collide_height : float
@export var target_world_collide_y : float
@export var game_steps_since_execute : int
@export var grabbing_agent : Agent

@export var server_knows := false
@export var client_knows := false
var mark_for_drop := {}
var try_grab_pickup := false
var mark_for_grenade_throw := false
var ungrabbable = false
var in_smoke = false
@export var step_seen : int = 0
@export var noticed : int = 0

enum AttackStep {
	ORIENTING,
	ATTACKING,
	BACKPACKING,
}
@export var attack_step := AttackStep.ORIENTING

@export var detected_weapons = []

func in_incapacitated_state() -> bool:
	return state in [States.GRABBED, States.STUNNED, States.DEAD, States.EXFILTRATED]


func in_standing_state() -> bool:
	return state in [States.STAND, States.WALK, States.RUN]


func in_crouching_state() -> bool:
	return state in [States.CROUCH, States.CROUCH_WALK]


func in_prone_state() -> bool:
	return state in [States.PRONE, States.CRAWL]


func in_moving_state() -> bool:
	return state in [States.WALK, States.RUN, States.CROUCH_WALK, States.CRAWL]


func can_crouch():
	return not _crouch_ray.is_colliding()


func can_prone():
	return not _prone_ray.is_colliding()


func can_stand():
	return not _stand_ray.is_colliding()


func get_required_y_rotation(aimed_position) -> float:
	var initial_dir = global_position.direction_to(aimed_position)
	var two_d_target = Vector2(initial_dir.x, initial_dir.z).normalized()
	return two_d_target.angle_to(Vector2.DOWN)


func perform_action():
	game_steps_since_execute = 0
	if len(queued_action) == 0:
		action_complete(true, false)
		return
	match queued_action[0]:
		GameActions.GO_STAND:
			_anim_state.travel("Stand")
			state = States.STAND
		GameActions.GO_CROUCH:
			_anim_state.travel("Crouch")
			state = States.CROUCH
		GameActions.GO_PRONE:
			_anim_state.travel("B_Prone")
			state = States.PRONE
		GameActions.RUN_TO_POS:
			_anim_state.travel("B_Run")
			_nav_agent.target_position = queued_action[1]
			rotation.y = get_required_y_rotation(queued_action[1])
			state = States.RUN
		GameActions.WALK_TO_POS:
			_anim_state.travel("B_Walk")
			_nav_agent.target_position = queued_action[1]
			rotation.y = get_required_y_rotation(queued_action[1])
			state = States.WALK
		GameActions.CROUCH_WALK_TO_POS:
			_anim_state.travel("B_Crouch_Walk")
			_nav_agent.target_position = queued_action[1]
			rotation.y = get_required_y_rotation(queued_action[1])
			state = States.CROUCH_WALK
		GameActions.CRAWL_TO_POS:
			_anim_state.travel("B_Crawl")
			_nav_agent.target_position = queued_action[1]
			rotation.y = get_required_y_rotation(queued_action[1])
			state = States.CRAWL
		GameActions.LOOK_AROUND:
			target_direction = get_required_y_rotation(queued_action[1])
		GameActions.CHANGE_ITEM:
			ungrabbable = true
			_mesh.visible = true
			if selected_item > -1:
				match held_items[selected_item]:
					"box":
						$Agent/Box.visible = false
					"body_armor":
						$Agent/game_rig/Skeleton3D/Helmet.visible = false
					"cigar":
						$Agent/game_rig/Skeleton3D/Cigar.visible = false
			selected_item = queued_action[1]
			if selected_item == -1:
				return
			match held_items[selected_item]:
				"box":
					$Agent/Box.visible = true
					_mesh.visible = false
					state = States.STAND
				"body_armor":
					$Agent/game_rig/Skeleton3D/Helmet.visible = true
				"cigar":
					$Agent/game_rig/Skeleton3D/Cigar.visible = true
		GameActions.CHANGE_WEAPON:
			selected_weapon = queued_action[1]
			var actual_weapon = (held_weapons[selected_weapon] as String).split("_", true, 3)[3]
			for weapon_mesh in _held_weapon_meshes:
				_held_weapon_meshes[weapon_mesh].visible = false
			if actual_weapon != "fist":
				_held_weapon_meshes[actual_weapon].visible = true
		GameActions.PICK_UP_WEAPON:
			 # point to pickup before picking up pickup
			var pickup = GameRefs.get_pickup_node(queued_action[1])
			target_direction = get_required_y_rotation(Vector3(pickup.position.x, pickup.position.y, pickup.position.z))
			if in_standing_state():
				_anim_state.travel("Stand")
			elif in_crouching_state():
				_anim_state.travel("Crouch")
			attack_step = AttackStep.ORIENTING
		GameActions.DROP_WEAPON:
			 # direct to drop off before dropping off drop
			target_direction = get_required_y_rotation(queued_action[2])
			if in_standing_state():
				_anim_state.travel("Stand")
			elif in_crouching_state():
				_anim_state.travel("Crouch")
		GameActions.USE_WEAPON:
			target_direction = get_required_y_rotation(queued_action[1])
			if in_standing_state():
				_anim_state.travel("Stand")
			elif in_crouching_state():
				_anim_state.travel("Crouch")
			state = States.USING_WEAPON
			attack_step = AttackStep.ORIENTING
		GameActions.RELOAD_WEAPON:
			game_steps_since_execute = GameRefs.WEP[GameRefs.get_weapon_node(held_weapons[selected_weapon]).wep_id].reload_time * -1
		GameActions.HALT:
			if state in [States.RUN, States.WALK]:
				_anim_state.travel("Stand")
				state = States.STAND
			if state == States.CROUCH_WALK:
				_anim_state.travel("Crouch")
				state = States.CROUCH
			if state == States.CRAWL:
				_anim_state.travel("B_Prone")
				state = States.PRONE


@rpc("any_peer", "call_local", "reliable")
func agent_is_done(doneness : Agent.ActionDoneness):
	action_done = doneness


func action_complete(successfully : bool = true, no_flash : bool = false, single_mode : bool = false):
	if not single_mode:
		agent_is_done.rpc(ActionDoneness.SUCCESS if successfully else ActionDoneness.FAIL)
		if is_multiplayer_authority() and not no_flash:
			flash_outline(Color.GREEN if successfully else Color.RED)
	else:
		agent_is_done(ActionDoneness.SUCCESS if successfully else ActionDoneness.FAIL)
		if not no_flash:
			flash_outline(Color.GREEN if successfully else Color.RED)
	queued_action.clear()


func _ready() -> void:
	# set up sensors
	_eye_cone.points[1] = Vector3(view_across, 1, view_dist)
	_eye_cone.points[2] = Vector3(-view_across, 1, view_dist)
	_eye_cone.points[3] = Vector3(view_across, 1, view_dist)
	_eye_cone.points[4] = Vector3(-view_across, 1, view_dist)
	if is_multiplayer_authority():
		_eyes.collision_mask += 1024 # add in client side popup layer to collide with
	_ear_cylinder.radius = hearing_dist
	_body.collision_layer += 8 if player_id == 1 else 16
	# custom texture
	if not is_multiplayer_authority():
		skin_texture = "res://assets/models/Skins/enemy_agent.png"
	if skin_texture:
		_custom_skin_mat = StandardMaterial3D.new()
		var texture : Texture2D = load(skin_texture)
		_custom_skin_mat.albedo_texture = texture
		_mesh.set_surface_override_material(0, _custom_skin_mat)
	# outline shader
	_outline_mat = _outline_mat_base.duplicate()
	_mesh.set_surface_override_material(1, _outline_mat)
	$Agent/Box.set_surface_override_material(2, _outline_mat)
	$Agent/Box.visible = false
	$Agent/game_rig/Skeleton3D/Helmet.set_surface_override_material(1, _outline_mat)
	$Agent/game_rig/Skeleton3D/Helmet.visible = false
	$Agent/game_rig/Skeleton3D/Cigar.set_surface_override_material(1, _outline_mat)
	$Agent/game_rig/Skeleton3D/Cigar.visible = false
	# other visuals
	$CQCAnimationHelper/Sprite3D.visible = false
	_anim_state.start("Stand")
	_anim.advance(0)
	_active_item_icon.texture = null
	for weapon_mesh in _held_weapon_meshes:
		_held_weapon_meshes[weapon_mesh].visible = false
	visible = is_multiplayer_authority()


func decide_weapon_blend() -> Vector2:
	match GameRefs.get_held_weapon_attribute(self, selected_weapon, "type"):
		GameRefs.WeaponTypes.CQC:
			return Vector2.ONE
		GameRefs.WeaponTypes.SMALL:
			return Vector2.LEFT + Vector2.DOWN
		GameRefs.WeaponTypes.BIG:
			return Vector2.ONE * -1
		_:
			return Vector2.RIGHT + Vector2.UP


func take_damage(amount : int, is_stun : bool = false):
	if is_stun:
		stun_health = max(0, stun_health - amount)
		stun_time = 30 if stun_health > 0 else 120
		if stun_health > 0:
			_anim_state.travel("B_Hurt_Slammed")
		else:
			_anim_state.travel("B_Hurt_Collapse")
		state = States.GRABBED
	else:
		if selected_item > -1 and held_items[selected_item] != "body_armor":
			amount = max(1, amount/2)
		health = max(0, health - amount)
		stun_time = 10
		select_hurt_animation()
		state = States.HURT if health > 0 else States.DEAD


func select_hurt_animation():
	if health == 0:
		_anim_state.travel("B_Hurt_Collapse")
		return
	var cur_node = _anim_state.get_current_node()
	if cur_node.begins_with("B_Stand_") or cur_node in ["B_Walk", "B_Run", "B_CrouchToStand", "B_Hurt_Standing", "Stand"]:
		_anim_state.travel("B_Hurt_Standing")
	elif cur_node.begins_with("B_Crouch_") or cur_node in ["B_ProneToCrouch", "B_StandToCrouch", "Crouch", "B_Crouch_Walk"]:
		_anim_state.travel("B_Hurt_Crouching")
	else:
		_anim_state.travel("B_Hurt_Prone")


func flash_outline(color : Color):
	_outline_mat.albedo_color = color


func exfiltrate():
	visible = true
	state = States.EXFILTRATED
	var twe = create_tween()
	twe.set_parallel()
	twe.tween_property(_mesh, "transparency", 1.0, 2.0).from(0.0)
	twe.tween_property($Agent/Box, "transparency", 1.0, 2.0).from(0.0)
	twe.tween_property($Agent/game_rig/Skeleton3D/Helmet, "transparency", 1.0, 2.0).from(0.0)
	twe.tween_property($Agent, "position:y", -10.0, 2.0).from_current()
	twe.finished.connect(func(): visible = false)


func _physics_process(_d: float) -> void:
	var v_cone = Vector3(VIS_CONE_BASE.x * 2 * view_across, 1, VIS_CONE_BASE.y * view_dist/2.5)
	_vision_cone.scale = v_cone
	_outline_mat.albedo_color = _outline_mat.albedo_color.lerp(Color.BLACK, GENERAL_LERP_VAL / 3.0)
	if not in_incapacitated_state():
		detected_weapons = []
		for overlap in _pickup_range.get_overlapping_areas():
			detected_weapons.append(overlap.get_parent())
			overlap.get_parent().flash_weapon()
	$AgentIsActive.visible = not in_incapacitated_state()
	$AgentIsStunned.visible = state == States.STUNNED
	$AgentIsStunned.rotation.z += PI/20.0
	$AgentIsDead.visible = state == States.DEAD


func should_be_visible():
	if server_knows and multiplayer.is_server():
		return true
	if client_knows and not multiplayer.is_server():
		return true
	return false


func within_target() -> bool:
	return abs(rotation.y - target_direction) < 0.1 or abs(rotation.y - (target_direction - TAU)) < 0.1 or abs(rotation.y - (target_direction + TAU)) < 0.1


func _game_step(delta: float, single_mode : bool = false) -> void:
	# update agent generally
	game_steps_since_execute += 1
	noticed = max(noticed - 1, 0)
	if not single_mode:
		visible = should_be_visible()
	if single_mode or not is_multiplayer_authority() or (in_incapacitated_state() and not percieved_by_friendly) or selected_item == -1:
		_active_item_icon.texture = null
	elif selected_item > -1:
		_active_item_icon.texture = GameRefs.ITM[held_items[selected_item]].icon
	visible_level = 100
	if in_standing_state():
		target_world_collide_height = 0.962
		target_world_collide_y = 0.499
		collision_mask = 1 + 2 + 4
		visible_level = 50
	if in_crouching_state():
		target_world_collide_height = 0.666
		target_world_collide_y = 0.35
		collision_mask = 1 + 2
		visible_level = 25
	if in_prone_state():
		target_world_collide_height = 0.264
		target_world_collide_y = 0.15
		collision_mask = 1
		visible_level = 5
	_world_collide.position.y = lerpf(_world_collide.position.y, target_world_collide_y, GENERAL_LERP_VAL)
	(_world_collide.get_shape() as CylinderShape3D).height = lerpf(
			(_world_collide.get_shape() as CylinderShape3D).height,
			target_world_collide_height,
			GENERAL_LERP_VAL
	)
	if len(queued_action) > 0 and queued_action[0] != GameActions.RELOAD_WEAPON:
		weapons_animation_blend = weapons_animation_blend.lerp(decide_weapon_blend(), GENERAL_LERP_VAL)
	_anim.set("parameters/Crouch/blend_position", weapons_animation_blend)
	_anim.set("parameters/Stand/blend_position", weapons_animation_blend)
	_anim.advance(delta)
	visible_level = clamp(visible_level, 0, 100)
	target_visible_level = lerp(target_visible_level, visible_level, GENERAL_LERP_VAL)
	# update agent specifically
	if selected_item > -1:
		match held_items[selected_item]:
			"box":
				target_visible_level = 1
			"cigar":
				if game_steps_since_execute % 50 == 0 and not in_incapacitated_state():
					stun_health = min(5, stun_health + 1)
	if in_moving_state():
		if selected_item > -1 and held_items[selected_item] == "box":
			target_visible_level = 150
		velocity = global_position.direction_to(_nav_agent.get_next_path_position())
		velocity *= movement_speed
		match state:
			States.RUN:
				visible_level += 30
			States.WALK, States.CROUCH_WALK:
				velocity /= 2.0
				visible_level += 20
			States.CRAWL:
				velocity /= 2.5
				visible_level += 10
		move_and_slide()
		if len(queued_action) < 2:
			match state:
				States.WALK, States.RUN:
					_anim_state.travel("Stand")
					state = States.STAND
				States.CROUCH_WALK:
					_anim_state.travel("Crouch")
					state = States.CROUCH
				States.CRAWL:
					_anim_state.travel("B_Prone")
					state = States.PRONE
			action_complete()
			return
		if position.distance_to(queued_action[1]) < 0.3 or game_steps_since_execute > 10*60:
			position = _nav_agent.target_position
			if game_steps_since_execute > 10*60:
				position.y = 0.0
			match state:
				States.WALK, States.RUN:
					_anim_state.travel("Stand")
					state = States.STAND
				States.CROUCH_WALK:
					_anim_state.travel("Crouch")
					state = States.CROUCH
				States.CRAWL:
					_anim_state.travel("B_Prone")
					state = States.PRONE
			action_complete()
			return
	if state == States.STUNNED:
		visible_level = 50
		stun_time = max(0, stun_time - 1)
		if stun_time == 0:
			stun_health = 3
			_anim_state.travel("Crouch")
			state = States.CROUCH
	if state == States.GRABBED:
		visible_level = 100
		if grabbing_agent != null:
			global_position = grabbing_agent._cqc_anim_helper.global_position
			global_rotation = grabbing_agent._cqc_anim_helper.global_rotation
	if len(queued_action) == 0:
		action_complete(true, true, single_mode)
		return
	match queued_action[0]:
		GameActions.LOOK_AROUND:
			rotation.y = lerp_angle(rotation.y, target_direction, GENERAL_LERP_VAL)
			if within_target():
				rotation.y = target_direction
				action_complete()
		GameActions.CHANGE_ITEM:
			if game_steps_since_execute > 5:
				action_complete()
		GameActions.CHANGE_WEAPON:
			if weapons_animation_blend.distance_squared_to(decide_weapon_blend()) < 0.01:
				weapons_animation_blend = decide_weapon_blend()
				action_complete()
		GameActions.USE_WEAPON: #TODO
			match attack_step:
				AttackStep.ORIENTING:
					rotation.y = lerp_angle(rotation.y, target_direction, GENERAL_LERP_VAL)
					if within_target():
						rotation.y = target_direction
						_attack_orient_transition()
				AttackStep.ATTACKING:
					visible_level = 100
					match GameRefs.WEP[GameRefs.get_weapon_node(held_weapons[selected_weapon]).wep_id].type:
						GameRefs.WeaponTypes.THROWN:
							if game_steps_since_execute == 30:
								mark_for_grenade_throw = true
								GameRefs.get_weapon_node(held_weapons[selected_weapon]).reload_weapon()
						GameRefs.WeaponTypes.PLACED:
							if game_steps_since_execute == 20:
								_anim_state.travel("Stand")
						GameRefs.WeaponTypes.CQC:
							var cqc_lerp_value = float(clamp(max(game_steps_since_execute - 20, 0)/60.0, 0.0, 1.0))
							_cqc_anim_helper.position = CQC_START.lerp(CQC_END, cqc_lerp_value)
							_cqc_anim_helper.rotation.y = lerp_angle(-PI/2, 0, cqc_lerp_value)
						GameRefs.WeaponTypes.SMALL, GameRefs.WeaponTypes.BIG:
							pass
		GameActions.PICK_UP_WEAPON:
			match attack_step:
				AttackStep.ORIENTING:
					rotation.y = lerp_angle(rotation.y, target_direction, GENERAL_LERP_VAL)
					if within_target():
						rotation.y = target_direction
						attack_step = AttackStep.BACKPACKING
						game_steps_since_execute = 0
				AttackStep.BACKPACKING:
					if game_steps_since_execute < 30:
						visible_level = 100
					if game_steps_since_execute == 30:
						try_grab_pickup = true
						held_weapons.append(queued_action[1])
					if game_steps_since_execute > 39:
						action_complete()
		GameActions.DROP_WEAPON:
			rotation.y = lerp_angle(rotation.y, target_direction, GENERAL_LERP_VAL)
			if within_target():
				rotation.y = target_direction
				mark_for_drop = {
					position = queued_action[2],
					wep_ind = queued_action[1],
					wep_node = held_weapons[queued_action[1]]
				}
				action_complete()
		GameActions.RELOAD_WEAPON:
			if game_steps_since_execute < -50:
				weapons_animation_blend = weapons_animation_blend.lerp(Vector2.ONE, GENERAL_LERP_VAL)
			if game_steps_since_execute == -20:
				GameRefs.get_weapon_node(held_weapons[selected_weapon]).reload_weapon()
			if game_steps_since_execute > -20:
				weapons_animation_blend = weapons_animation_blend.lerp(decide_weapon_blend(), GENERAL_LERP_VAL)
			if game_steps_since_execute == 0:
				weapons_animation_blend = decide_weapon_blend()
				action_complete()


func _attack_orient_transition():
	game_steps_since_execute = 0
	if _anim_state.get_current_node() == "Stand":
		attack_step = AttackStep.ATTACKING
		match GameRefs.WEP[GameRefs.get_weapon_node(held_weapons[selected_weapon]).wep_id].type:
			GameRefs.WeaponTypes.CQC:
				state = States.CQC_GRAB
			GameRefs.WeaponTypes.SMALL:
				state = States.FIRE_GUN
				_anim_state.travel("B_Stand_Attack_SmallArms")
			GameRefs.WeaponTypes.BIG:
				state = States.FIRE_GUN
				_anim_state.travel("B_Stand_Attack_BigArms")
			GameRefs.WeaponTypes.THROWN:
				state = States.THROW_BOMB
				_anim_state.travel("B_Stand_Attack_Grenade")
			GameRefs.WeaponTypes.PLACED:
				_anim_state.travel("Crouch")
	elif _anim_state.get_current_node() == "Crouch":
		match GameRefs.WEP[GameRefs.get_weapon_node(held_weapons[selected_weapon]).wep_id].type:
			GameRefs.WeaponTypes.SMALL:
				attack_step = AttackStep.ATTACKING
				_anim_state.travel("B_Crouch_Attack_SmallArms")
			GameRefs.WeaponTypes.BIG:
				attack_step = AttackStep.ATTACKING
				_anim_state.travel("B_Crouch_Attack_BigArms")
			GameRefs.WeaponTypes.THROWN:
				attack_step = AttackStep.ATTACKING
				_anim_state.travel("B_Crouch_Attack_Grenade")
			GameRefs.WeaponTypes.PLACED:
				pass


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name.begins_with("B_Hurt") and not anim_name in ["B_Hurt_Stunned", "B_Hurt_WakeUp", "B_Hurt_Collapse"]:
		action_complete(false)
	if anim_name == "B_Hurt_Collapse":
		if health == 0:
			_anim_state.travel("B_Dead")
		if stun_health == 0:
			_anim_state.travel("B_Hurt_Stunned")
	if state == States.GRABBED:
		state = States.STUNNED
	if len(queued_action) == 0:
		action_complete(true, true)
		return
	match queued_action[0]:
		GameActions.GO_STAND when anim_name == "B_CrouchToStand":
			action_complete()
		GameActions.GO_CROUCH when anim_name == "B_StandToCrouch":
			action_complete()
		GameActions.GO_CROUCH when anim_name == "B_ProneToCrouch":
			action_complete()
		GameActions.GO_PRONE when anim_name == "B_CrouchToProne":
			action_complete()
		GameActions.USE_WEAPON when anim_name in ["B_Stand_Attack_SmallArms", "B_Stand_Attack_BigArms", "B_Stand_Attack_Grenade", "B_Stand_Attack_Slam", "B_Stand_Attack_Whiff"]:
			action_complete()
		GameActions.USE_WEAPON when anim_name in ["B_Crouch_Attack_SmallArms", "B_Crouch_Attack_BigArms", "B_Crouch_Attack_Grenade"]:
			action_complete()
