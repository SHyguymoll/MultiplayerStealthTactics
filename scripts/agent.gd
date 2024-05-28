class_name Agent
extends CharacterBody3D

signal action_completed(actor : Agent)
signal action_interrupted(interrupted_actor : Agent)
signal agent_selected(agent : Agent)

signal spotted_agent(spotter : Agent, spottee : Agent)
signal unspotted_agent(unspotter : Agent, unspottee : Agent)
signal spotted_element(element : Node3D)
signal unspotted_element(element : Node3D)
signal heard_sound(listener : Agent, sound : Node3D)
signal agent_died(deceased : Agent)

var view_dist : float = 2.5 #length of vision "cone" (really a pyramid)
var view_across : float = 1 #size of vision pyramid base
var eye_strength : float = 0.8 #multiplier applied to vision pyramid in relation to view target distance

var hearing_dist : float = 1.5 #distance of furthest possibly heard audio event
var ear_strength : float = 1 #multiplier applied to ear cylinder in relation to audio target distance

var movement_dist : float = 7.0 #distance of furthest possible movement
var movement_speed : float = 2.75 #movement speed when running (divided by 2 for walking, 2.5 for prone)

var camo_level : int #bounded from 0 to 100, based on current state

var weapon_accuracy : float #bounded from 0.00 to 1.00, based on movement and weapon usage

var held_items : Array[String] = [] #max length should be 3
var held_weapons : Array[GameWeapon] = [] #max length should be 2

var selected_item : int = -1 #index for item (-1 for no item)
var selected_weapon : int = -1 #index for weapon (-1 for no weapon)

var percieved_by_friendly := false #determines if hud is updated

@export var skin_texture : String

@onready var _anim : AnimationTree = $AnimationTree
@onready var _anim_state : AnimationNodeStateMachinePlayback = _anim.get("parameters/playback")
@onready var _mesh : MeshInstance3D = $Agent/game_rig/Skeleton3D/Mesh
@onready var _custom_skin_mat : StandardMaterial3D
var _outline_mat_base = preload("res://assets/models/materials/agent_outline.tres")
var _outline_mat : StandardMaterial3D
@onready var _eyes : Area3D = $Eyes
@onready var _eye_cone : ConvexPolygonShape3D = _eyes.get_node("CollisionShape3D").shape
@onready var _ears : Area3D = $Ears
@onready var _ear_cylinder : CylinderShape3D = _ears.get_node("CollisionShape3D").shape
@onready var _body : Area3D = $Body
@onready var _world_collide : CollisionShape3D = $WorldCollision
@onready var _prone_ray : RayCast3D = $ProneCheck
@onready var _crouch_ray : RayCast3D = $CrouchCheck
@onready var _stand_ray : RayCast3D = $StandCheck
@onready var _nav_agent : NavigationAgent3D = $NavigationAgent3D
@onready var _active_item_icon : Sprite3D = $ActiveItem

# Actions are stored as an enum in order to make serialization much easier
# each agent will be stored in the action timeline as an array, where the first entry is the action,
# and any important metadata (position, rotation, selection, etc.) follows.
enum GameActions {
	GO_STAND, GO_CROUCH, GO_PRONE,
	RUN_TO_POS, WALK_TO_POS, CROUCH_WALK_TO_POS, CRAWL_TO_POS,
	LOOK_AROUND,
	CHANGE_ITEM, CHANGE_WEAPON,
	PICK_UP_ITEM, PICK_UP_WEAPON,
	USE_WEAPON, RELOAD_WEAPON,
	HALT,
}
#format is [GameActions, ... (game action parameters)]
var queued_action = []

enum States {
	STAND, CROUCH, PRONE,
	RUN, WALK, CROUCH_WALK, CRAWL,
	USING_ITEM, USING_WEAPON, RELOADING_WEAPON,
	HURT, STUNNED, DEAD,
}
@export var state : States = States.STAND

var target_direction : float
var stun_time : int = 0
var health : int = 10
var target_camo_level : int
var target_accuracy : float
var weapons_animation_blend := Vector2.ONE
var target_head_rot_off_y : float = 0.0 #rot of head in relation to body rot
var target_world_collide_height : float
var target_world_collide_y : float

func in_incapacitated_state() -> bool:
	return state in [States.STUNNED, States.DEAD]


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


func perform_action():
	if len(queued_action) == 0:
		action_completed.emit(self)
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
			state = States.RUN
		GameActions.WALK_TO_POS:
			_anim_state.travel("B_Walk")
			_nav_agent.target_position = queued_action[1]
			state = States.WALK
		GameActions.CROUCH_WALK_TO_POS:
			_anim_state.travel("B_Crouch_Walk")
			_nav_agent.target_position = queued_action[1]
			state = States.CROUCH_WALK
		GameActions.CRAWL_TO_POS:
			_anim_state.travel("B_Crawl")
			_nav_agent.target_position = queued_action[1]
			state = States.CRAWL
		GameActions.LOOK_AROUND:
			target_direction = queued_action[1]
		GameActions.CHANGE_ITEM:
			if queued_action[1] == GameIcons.ITM.none:
				selected_item = -1
			else:
				selected_item = held_items.find(queued_action[1])
		GameActions.CHANGE_WEAPON:
			pass
		GameActions.PICK_UP_ITEM:
			pass
		GameActions.PICK_UP_WEAPON:
			pass
		GameActions.USE_WEAPON:
			if in_standing_state():
				if selected_weapon == -1:
					pass
					return
				match held_weapons[selected_weapon].type:
					GameWeapon.Types.SMALL:
						_anim_state.travel("B_Stand_Attack_SmallArms")
					GameWeapon.Types.BIG:
						_anim_state.travel("B_Stand_Attack_BigArms")
					GameWeapon.Types.THROWN:
						_anim_state.travel("B_Stand_Attack_Grenade")
					GameWeapon.Types.PLACED:
						_anim_state.travel("Crouch")
			elif in_crouching_state():
				if selected_weapon == -1:
					return
				match held_weapons[selected_weapon].type:
					GameWeapon.Types.SMALL:
						_anim_state.travel("B_Stand_Attack_SmallArms")
					GameWeapon.Types.BIG:
						_anim_state.travel("B_Stand_Attack_BigArms")
					GameWeapon.Types.THROWN:
						_anim_state.travel("B_Stand_Attack_Grenade")
					GameWeapon.Types.PLACED:
						pass
						#_anim_state.travel("B_Crouch_Grenade")
			state = States.USING_WEAPON
		GameActions.RELOAD_WEAPON:
			pass
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

#func _enter_tree() -> void:
	#set_multiplayer_authority(name.split("_")[0].to_int())


func update_eye_cone(dist_mult : float):
	_eye_cone.points[1] = Vector3(
					-view_across * dist_mult * dist_mult,
					view_across * dist_mult * dist_mult,
					view_dist * dist_mult)
	_eye_cone.points[2] = Vector3(
					view_across * dist_mult * dist_mult,
					view_across * dist_mult * dist_mult,
					view_dist * dist_mult)
	_eye_cone.points[3] = Vector3(
					view_across * dist_mult * dist_mult,
					-view_across * dist_mult * dist_mult,
					view_dist * dist_mult)
	_eye_cone.points[4] = Vector3(
					-view_across * dist_mult * dist_mult,
					-view_across * dist_mult * dist_mult,
					view_dist * dist_mult)


func update_ear_radius(mult : float):
	_ear_cylinder.radius = hearing_dist * mult


func set_clickable(clickable : bool):
	($MouseClick as Area3D).input_ray_pickable = clickable


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
	target_head_rot_off_y = $DebugValues/DuringGame/HeadScroll.value
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
	update_eye_cone(1.0)
	update_ear_radius(1.0)
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
	# debug
	# debug_setup()


func _process(_delta: float) -> void:
	# debug_process()

	pass


func decide_head_position() -> Vector3:
	if in_standing_state():
		return Vector3(0, 0.889, 0.06)
	elif in_crouching_state():
		return Vector3(0, 0.732, 0.175)
	elif in_prone_state():
		return Vector3(0, 0.195, 0.537)
	else:
		return _eyes.position


func decide_weapon_blend() -> Vector2:
	if selected_weapon > -1:
		match held_weapons[selected_weapon].type:
			GameWeapon.Types.SMALL:
				return Vector2(-1, 1)
			GameWeapon.Types.BIG:
				return Vector2(-1, -1)
			_:
				return Vector2(1, -1)
	else:
		return Vector2.ONE


func _physics_process(delta: float) -> void:
	_outline_mat.albedo_color = _outline_mat.albedo_color.lerp(Color.BLACK, 0.2)


func _game_step(delta: float) -> void:
	# update agent generally
	if not is_multiplayer_authority() or (in_incapacitated_state() and not percieved_by_friendly) or selected_item == -1:
		_active_item_icon.visible = false
	elif selected_item > -1:
		_active_item_icon.texture = GameIcons.ITM[held_items[selected_item]]
		_active_item_icon.visible = true
	_eyes.position = _eyes.position.lerp(decide_head_position(), 0.2)
	_eyes.rotation.y = target_head_rot_off_y
	update_eye_cone(eye_strength)
	update_ear_radius(ear_strength)
	if in_standing_state() or in_crouching_state():
		(_body.get_node("Middle") as CollisionShape3D).disabled = false
	else:
		(_body.get_node("Middle") as CollisionShape3D).disabled = true
	if in_standing_state():
		(_body.get_node("Top") as CollisionShape3D).disabled = false
	else:
		(_body.get_node("Top") as CollisionShape3D).disabled = true
	if in_standing_state():
		target_world_collide_height = 0.962
		target_world_collide_y = 0.499
		collision_mask = 1 + 64 + 128
	if in_crouching_state():
		target_world_collide_height = 0.666
		target_world_collide_y = 0.35
		collision_mask = 1 + 64
	if in_prone_state():
		target_world_collide_height = 0.264
		target_world_collide_y = 0.15
		collision_mask = 1
	_world_collide.position.y = lerpf(_world_collide.position.y, target_world_collide_y, 0.2)
	(_world_collide.get_shape() as BoxShape3D).size.y = lerpf(
			(_world_collide.get_shape() as BoxShape3D).size.y,
			target_world_collide_height,
			0.2
	)
	weapons_animation_blend = weapons_animation_blend.lerp(decide_weapon_blend(), 0.2)
	_anim.set("parameters/Crouch/blend_position", weapons_animation_blend)
	_anim.set("parameters/Stand/blend_position", weapons_animation_blend)
	_anim.advance(delta)
	#animation_finished = anim_traversal_endpoint == _anim_state.get_current_node()
	#if animation_finished:
		#action_completed.emit(self)
	# update agent specifically
	if len(queued_action) == 0:
		return
	if in_moving_state():
		velocity = global_position.direction_to(_nav_agent.get_next_path_position())
		look_at(_nav_agent.get_next_path_position())
		rotation *= Vector3.DOWN
		#velocity *= min(movement_speed, global_position.distance_to(_nav_agent.get_next_path_position()))
		velocity *= movement_speed
		match state:
			States.WALK, States.CROUCH_WALK:
				velocity /= 2.0
			States.CRAWL:
				velocity /= 2.5
		#$DebugLabel3D.text = str(velocity) + "\n" + str(_nav_agent.target_position) + "\n" + str(global_position.distance_to(_nav_agent.get_next_path_position()))
		move_and_slide()
		if global_position.distance_to(_nav_agent.get_next_path_position()) < 0.5:
			match state:
				States.WALK, States.RUN:
					state = States.STAND
				States.CROUCH_WALK:
					state = States.CROUCH
				States.CRAWL:
					state = States.PRONE
			#action_completed.emit(self)
	match queued_action[0]:
		GameActions.LOOK_AROUND:
			target_head_rot_off_y = lerpf(target_head_rot_off_y, target_direction, 0.2)
			if target_head_rot_off_y == target_direction:
				pass
			elif abs(target_direction - target_head_rot_off_y) < 0.01:
				target_head_rot_off_y = target_direction
				action_completed.emit(self)
		GameActions.USE_WEAPON:
			target_head_rot_off_y = lerpf(target_head_rot_off_y, target_direction, 0.2)
			if target_head_rot_off_y == target_direction:
				pass
			elif abs(target_direction - target_head_rot_off_y) < 0.01:
				target_head_rot_off_y = target_direction
				action_completed.emit(self)
	#if is_multiplayer_authority():
		#var move_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		#position = position + Vector3(move_dir.x, 0, move_dir.y)


func _agent_clicked(camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouse:
		if event.button_mask == MOUSE_BUTTON_MASK_LEFT:
			agent_selected.emit(self)


func flash_outline(color : Color):
	_outline_mat.albedo_color = color


func _on_eyes_area_entered(area: Area3D) -> void:
	var par = area.get_parent()
	if par is Agent:
		spotted_agent.emit(self, par)
	else:
		spotted_element.emit(par)


func _on_eyes_area_exited(area: Area3D) -> void:
	var par = area.get_parent()
	if par is Agent:
		unspotted_agent.emit(self, par)
	else:
		unspotted_element.emit(par)


func _on_ears_area_entered(area: Area3D) -> void:
	heard_sound.emit(area.get_parent())


func _on_animation_finished(anim_name: StringName) -> void:
	print(name, ": ", anim_name)
	if anim_name.begins_with("B_Hurt"):
		action_interrupted.emit(self)
	if len(queued_action) == 0:
		return
	match queued_action[0]:
		GameActions.GO_STAND when anim_name == "B_CrouchToStand":
			action_completed.emit(self)
		GameActions.GO_CROUCH when anim_name == "B_StandToCrouch":
			action_completed.emit(self)
		GameActions.GO_CROUCH when anim_name == "B_ProneToCrouch":
			action_completed.emit(self)
		GameActions.GO_PRONE when anim_name == "B_CrouchToProne":
			action_completed.emit(self)
		GameActions.USE_WEAPON when anim_name in ["B_Stand_Attack_SmallArms", "B_Stand_Attack_BigArms", "B_Stand_Attack_Grenade", "B_Stand_Attack_Slam"]:
			action_completed.emit(self)
		GameActions.USE_WEAPON when anim_name in ["B_Crouch_Attack_SmallArms", "B_Crouch_Attack_BigArms", "B_Crouch_Attack_Grenade"]:
			action_completed.emit(self)


func _on_animation_started(anim_name: StringName) -> void:
	print(name, ": ", anim_name)
	if anim_name == "B_Dead":
		agent_died.emit(self)
	if len(queued_action) == 0:
		return
	#if queued_action[0] in [GameActions.GO_STAND, GameActions.RUN_TO_POS, GameActions.WALK_TO_POS, GameActions.HALT, GameActions.USE_WEAPON] and anim_name in ["B_Stand_Unarmed", "B_Stand_SmallArms", "B_Stand_BigArms", "B_Stand_Grenade"]:
		#action_completed.emit(self)
	#if queued_action[0] in [GameActions.GO_CROUCH, GameActions.CROUCH_WALK_TO_POS, GameActions.HALT, GameActions.USE_WEAPON] and anim_name in ["B_Crouch_Unarmed", "B_Crouch_SmallArms", "B_Crouch_BigArms", "B_Crouch_Grenade"]:
		#action_completed.emit(self)
	#if queued_action[0] in [GameActions.GO_PRONE, GameActions.CRAWL_TO_POS, GameActions.HALT] and anim_name in ["B_Prone"]:
		#action_completed.emit(self)
	#if anim_name.begins_with("B_Hurt_"):
		#action_interrupted.emit(self)
