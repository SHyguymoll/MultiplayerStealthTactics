class_name Agent
extends CharacterBody3D

signal agent_selected(agent : Agent)
signal agent_died(deceased : Agent)

const CQC_START = Vector3(0, 0, 0.48)
const CQC_END = Vector3(0.545, 0, 0)
const GENERAL_LERP_VAL = 0.2

var view_dist : float = 2.5 #length of vision "cone" (really a pyramid)
var view_across : float = 1 #size of vision pyramid base
var eye_strength : float = 0.15 #multiplier applied to vision pyramid in relation to view target distance

var hearing_dist : float = 1.5 #distance of furthest possibly heard audio event
var ear_strength : float = 1 #multiplier applied to ear cylinder in relation to audio target distance

var movement_dist : float = 7.0 #distance of furthest possible movement
var movement_speed : float = 2.75 #movement speed when running (divided by 2 for walking, 2.5 for prone)

@export var visible_level : int = 50 #bounded from 0 to 100, based on current state

var held_items : Array = [] #max length should be 3, only uses Strings
var held_weapons : Array[GameWeapon] = [] #max length should be 3 (including fist)

@export var selected_item : int = -1 #index for item (-1 for no item)
@export var selected_weapon : int = 0 #index for weapon (0 for fist)

@export var percieved_by_friendly := false #determines if hud is updated

@export var skin_texture : String

@onready var _anim : AnimationTree = $AnimationTree
@onready var _anim_state : AnimationNodeStateMachinePlayback = _anim.get("parameters/playback")
@onready var _mesh : MeshInstance3D = $Agent/game_rig/Skeleton3D/Mesh
@onready var _custom_skin_mat : StandardMaterial3D
var _outline_mat_base = preload("res://assets/models/materials/agent_outline.tres")
var _outline_mat : StandardMaterial3D
@onready var _eyes : Area3D = $Eyes
@onready var _eye_cone : ConvexPolygonShape3D = $Eyes/CollisionShape3D.shape
@onready var _ears : Area3D = $Ears
@onready var _ear_cylinder : CylinderShape3D = _ears.get_node("CollisionShape3D").shape
@onready var _body : Area3D = $Body
@onready var _world_collide : CollisionShape3D = $WorldCollision
@onready var _prone_ray : RayCast3D = $ProneCheck
@onready var _crouch_ray : RayCast3D = $CrouchCheck
@onready var _stand_ray : RayCast3D = $StandCheck
@onready var _cqc_anim_helper : Node3D = $CQCAnimationHelper
@onready var _nav_agent : NavigationAgent3D = $NavigationAgent3D
@onready var _active_item_icon : Sprite3D = $ActiveItem
@onready var _held_weapon_meshes = {
	pistol = $Agent/game_rig/Skeleton3D/Pistol,
	rifle = $Agent/game_rig/Skeleton3D/Rifle,
	shotgun = $Agent/game_rig/Skeleton3D/Shotgun,
	grenade_frag = $Agent/game_rig/Skeleton3D/GrenadeFrag,
	grenade_smoke = $Agent/game_rig/Skeleton3D/GrenadeSmoke,
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

enum AttackStep {
	ORIENTING,
	ATTACKING,
}
@export var attack_step := AttackStep.ORIENTING

@export var detected : Array = []

func in_incapacitated_state() -> bool:
	return state in [States.GRABBED, States.STUNNED, States.DEAD]


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
			if queued_action[1] == "none":
				selected_item = -1
			else:
				selected_item = held_items.find(queued_action[1])
		GameActions.CHANGE_WEAPON:
			selected_weapon = queued_action[1]
			for weapon_mesh in _held_weapon_meshes:
				_held_weapon_meshes[weapon_mesh].visible = false
			if held_weapons[selected_weapon].wep_name != "fist":
				_held_weapon_meshes[held_weapons[selected_weapon].wep_name].visible = true
		GameActions.PICK_UP_WEAPON:
			pass
		GameActions.USE_WEAPON:
			target_direction = get_required_y_rotation(queued_action[1])
			if in_standing_state():
				_anim_state.travel("Stand")
			elif in_crouching_state():
				_anim_state.travel("Crouch")
			state = States.USING_WEAPON
			attack_step = AttackStep.ORIENTING
		GameActions.RELOAD_WEAPON:
			game_steps_since_execute = GameRefs.WEP[held_weapons[selected_weapon].wep_name].reload_time * -1
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


func action_complete(successfully : bool = true, no_flash : bool = false):
	agent_is_done.rpc(ActionDoneness.SUCCESS if successfully else ActionDoneness.FAIL)
	#action_done = ActionDoneness.SUCCESS if successfully else ActionDoneness.FAIL
	queued_action.clear()
	if is_multiplayer_authority() and not no_flash:
		flash_outline(Color.GREEN if successfully else Color.RED)


func debug_setup():
	# states
	$DebugValues/DuringGame/StateScroll.min_value = 0
	$DebugValues/DuringGame/StateScroll.max_value = len(States.keys()) - 1
	$DebugValues/DuringGame/StateScroll.value = 0
	$DebugValues/DuringGame/StateScroll.step = 1
	# eyes
	$DebugValues/DuringGame/EyeScroll.min_value = 0.05
	$DebugValues/DuringGame/EyeScroll.max_value = 1
	$DebugValues/DuringGame/EyeScroll.value = 1
	$DebugValues/GameSetup/EyeLengthScroll.min_value = 0.5
	$DebugValues/GameSetup/EyeLengthScroll.max_value = 4.5
	$DebugValues/GameSetup/EyeLengthScroll.value = 2.5
	$DebugValues/GameSetup/EyeAcrossScroll.min_value = 0.5
	$DebugValues/GameSetup/EyeAcrossScroll.max_value = 1.5
	$DebugValues/GameSetup/EyeAcrossScroll.value = 1
	# ears
	$DebugValues/DuringGame/EarScroll.min_value = 0
	$DebugValues/DuringGame/EarScroll.max_value = 1
	$DebugValues/DuringGame/EarScroll.value = 1
	$DebugValues/GameSetup/EarScroll.min_value = 0.25
	$DebugValues/GameSetup/EarScroll.max_value = 3
	$DebugValues/GameSetup/EarScroll.value = 1.5
	# head rotation
	$DebugValues/DuringGame/HeadScroll.min_value = -(PI * 0.9)/2
	$DebugValues/DuringGame/HeadScroll.max_value = (PI * 0.9)/2
	$DebugValues/DuringGame/HeadScroll.value = 0
	$DebugValues/DuringGame/HeadScroll.step = 0.01


func debug_process():
	$DebugValues/DuringGame/StateLabel.text = States.keys()[state]
	state = $DebugValues/DuringGame/StateScroll.value
	view_dist = $DebugValues/GameSetup/EyeLengthScroll.value
	view_across = $DebugValues/GameSetup/EyeAcrossScroll.value
	hearing_dist = $DebugValues/GameSetup/EarScroll.value

	eye_strength = $DebugValues/DuringGame/EyeScroll.value
	ear_strength = $DebugValues/DuringGame/EarScroll.value
	#target_head_rot_off_y = $DebugValues/DuringGame/HeadScroll.value
	$DebugCamera.position = lerp(
			Vector3(1.56, 0.553, 0.802),
			Vector3(0.969, 3.016, 0.634),
			$DebugValues/CameraScroll.value)
	$DebugCamera.rotation_degrees = lerp(
			Vector3(0, 61.3, 0),
			Vector3(-74.9, 61.3, 0.629),
			$DebugValues/CameraScroll.value)


func _ready() -> void:
	# set up sensors
	_eye_cone.points[1] = Vector3(view_across, view_across, view_dist)
	_eye_cone.points[2] = Vector3(-view_across, view_across, view_dist)
	_eye_cone.points[3] = Vector3(view_across, -view_across, view_dist)
	_eye_cone.points[4] = Vector3(-view_across, -view_across, view_dist)
	if is_multiplayer_authority():
		_eyes.collision_mask += 1024 # add in client side popup layer to collide with
	_ear_cylinder.radius = hearing_dist
	# custom texture
	if skin_texture:
		_custom_skin_mat = StandardMaterial3D.new()
		var texture : Texture2D = load(skin_texture)
		_custom_skin_mat.albedo_texture = texture
		_mesh.set_surface_override_material(0, _custom_skin_mat)
	# outline shader
	_outline_mat = _outline_mat_base.duplicate()
	_mesh.set_surface_override_material(1, _outline_mat)
	# other visuals
	_anim_state.start("Stand")
	_anim.advance(0)
	_active_item_icon.texture = null
	for weapon_mesh in _held_weapon_meshes:
		_held_weapon_meshes[weapon_mesh].visible = false
	# debug
	# debug_setup()


func _process(_delta: float) -> void:
	# debug_process()

	pass

func decide_weapon_blend() -> Vector2:
	match GameRefs.WEP[held_weapons[selected_weapon].wep_name].type:
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
	else:
		health = max(0, health - amount)


func select_hurt_animation():
	var cur_node = _anim_state.get_current_node()
	if cur_node.begins_with("B_Stand_") or cur_node in ["B_Walk", "B_Run", "B_CrouchToStand", "B_Hurt_Standing", "Stand"]:
		_anim_state.travel("B_Hurt_Standing")
	elif cur_node.begins_with("B_Crouch_") or cur_node in ["B_ProneToCrouch", "B_StandToCrouch", "Crouch", "B_Crouch_Walk"]:
		_anim_state.travel("B_Hurt_Crouching")
	else:
		_anim_state.travel("B_Hurt_Prone")


func flash_outline(color : Color):
	_outline_mat.albedo_color = color


func _physics_process(delta: float) -> void:
	_outline_mat.albedo_color = _outline_mat.albedo_color.lerp(Color.BLACK, GENERAL_LERP_VAL)


func _game_step(delta: float) -> void:
	# update agent generally
	game_steps_since_execute += 1
	if not is_multiplayer_authority() or (in_incapacitated_state() and not percieved_by_friendly) or selected_item == -1:
		_active_item_icon.visible = false
	elif selected_item > -1:
		_active_item_icon.texture = GameRefs.ITM[held_items[selected_item]].icon
		_active_item_icon.visible = true
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
	# update agent specifically
	if in_moving_state():
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
		if _nav_agent.distance_to_target() < velocity.length(): # to always land on target
			velocity = velocity.normalized() * _nav_agent.distance_to_target()
		move_and_slide()
		if position.distance_to(queued_action[1]) < 0.2:
			position = _nav_agent.target_position
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
			_anim_state.travel("Crouch")
			state = States.CROUCH
	if state == States.GRABBED:
		visible_level = 100
		if grabbing_agent != null:
			global_position = grabbing_agent._cqc_anim_helper.global_position
			global_rotation = grabbing_agent._cqc_anim_helper.global_rotation
	if len(queued_action) == 0:
		action_complete(true, true)
		return
	match queued_action[0]:
		GameActions.LOOK_AROUND:
			rotation.y = lerp_angle(rotation.y, target_direction, GENERAL_LERP_VAL)
			if abs(rotation.y - target_direction) < 0.1:
				rotation.y = target_direction
				action_complete()
		GameActions.CHANGE_WEAPON:
			if weapons_animation_blend.distance_squared_to(decide_weapon_blend()) == 0:
				action_complete()
			elif weapons_animation_blend.distance_squared_to(decide_weapon_blend()) < 0.01:
				weapons_animation_blend = decide_weapon_blend()
		GameActions.USE_WEAPON: #TODO
			match attack_step:
				AttackStep.ORIENTING:
					rotation.y = lerpf(rotation.y, target_direction, GENERAL_LERP_VAL)
					if abs(abs(rotation.y) - abs(target_direction)) < 0.1:
						rotation.y = target_direction
						_attack_orient_transition()
				AttackStep.ATTACKING:
					visible_level = 100
					match GameRefs.WEP[held_weapons[selected_weapon].wep_name].type:
						GameRefs.WeaponTypes.THROWN:
							if game_steps_since_execute == 30:
								pass
						GameRefs.WeaponTypes.PLACED:
							if game_steps_since_execute == 20:
								_anim_state.travel("Stand")
						GameRefs.WeaponTypes.CQC:
							var cqc_lerp_value = float(clamp(max(game_steps_since_execute - 20, 0)/60.0, 0.0, 1.0))
							_cqc_anim_helper.position = CQC_START.lerp(CQC_END, cqc_lerp_value)
							_cqc_anim_helper.rotation.y = lerp_angle(-PI/2, 0, cqc_lerp_value)
						GameRefs.WeaponTypes.SMALL, GameRefs.WeaponTypes.BIG:
							pass
		GameActions.RELOAD_WEAPON:
			if game_steps_since_execute < -50:
				weapons_animation_blend = weapons_animation_blend.lerp(Vector2.ONE, GENERAL_LERP_VAL)
			if game_steps_since_execute == -20:
				held_weapons[selected_weapon].reload_weapon()
			if game_steps_since_execute > -20:
				weapons_animation_blend = weapons_animation_blend.lerp(decide_weapon_blend(), GENERAL_LERP_VAL)
			if game_steps_since_execute == 0:
				weapons_animation_blend = decide_weapon_blend()
				action_complete()
	visible_level = clamp(visible_level, 0, 100)
	target_visible_level = lerp(target_visible_level, visible_level, GENERAL_LERP_VAL)
	$DebugLabel3D.text = str(target_visible_level)


func _attack_orient_transition():
	game_steps_since_execute = 0
	if _anim_state.get_current_node() == "Stand":
		attack_step = AttackStep.ATTACKING
		match GameRefs.WEP[held_weapons[selected_weapon].wep_name].type:
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
		match GameRefs.WEP[held_weapons[selected_weapon].wep_name].type:
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
	if anim_name.begins_with("B_Hurt") and not anim_name in ["B_Hurt_Stunned", "B_Hurt_WakeUp"]:
		action_complete(false)
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




func _on_animation_started(anim_name: StringName) -> void:
	if anim_name == "B_Dead":
		agent_died.emit(self)
	if len(queued_action) == 0:
		return
