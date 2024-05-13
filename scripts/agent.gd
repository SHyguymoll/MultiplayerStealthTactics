class_name Agent
extends CharacterBody3D

signal action_completed
signal action_interrupted
signal agent_died
signal action_chosen
signal agent_selected(agent : Agent)
signal agent_deselected(agent : Agent)

signal spotted_agent(other_agent : Agent)
signal spotted_element(element : Node3D)

var view_dist : float = 2.5 #length of vision "cone"
var view_across : float = 1 #"arc" of vision "cone"
var eye_strength : float = 1 #multiplier applied to vision "cone" in relation to view target distance

var hearing_dist : float = 1.5 #distance of furthest possibly heard audio event
var ear_strength : float = 1

var movement_dist : float #distance of furthest possible movement
var movement_speed : float #maximum movement speed per turn

var camo_level : int #bounded from 0 to 100

var weapon_accuracy : float #bounded from 0.00 to 1.00

var held_items : Array[String] = [] #max length should be 3
var held_weapons : Array[GameWeapon] = [] #max length should be 2

var selected_item : int = -1 #index for item
var selected_weapon : int = -1 #index for weapon

var player_id : int #id of player who brought the agent
var agent_already_selected : bool

@export var skin_texture : String

@onready var anim : AnimationTree = $AnimationTree
@onready var _mesh : MeshInstance3D = $Agent/game_rig/Skeleton3D/Mesh
@onready var _custom_skin_mat : StandardMaterial3D
var _outline_mat_base = preload("res://assets/models/materials/agent_outline.tres")
var _outline_mat : StandardMaterial3D
@onready var _eyes : ShapeCast3D = $Eyes
@onready var _eye_cone = _eyes.shape as ConvexPolygonShape3D
@onready var _ears : ShapeCast3D = $Ears
@onready var _ear_cylinder = _ears.shape as CylinderShape3D
@onready var _body : Area3D = $Body
@onready var _world_collide : CollisionShape3D = $WorldCollision


enum GameActions {
	GO_STAND, GO_CROUCH, GO_PRONE,
	MOVE_TO_POS, SNEAK_TO_POS, PARANOID_SNEAK_TO_POS,
	LOOK_AROUND,
	CHANGE_ITEM, CHANGE_WEAPON,
	PICK_UP_ITEM, PICK_UP_WEAPON,
	USE_ITEM, USE_WEAPON, RELOAD_WEAPON,
	HALT,
}
var queued_action : GameActions

enum States {
	STAND, CROUCH, PRONE,
	RUN, WALK, PARANOID_WALK, CROUCH_WALK, CRAWL,
	USING_ITEM, USING_WEAPON, RELOADING_WEAPON,
	HURT, STUNNED, DEAD,
}
@export var state : States = States.STAND

var target_position : Vector2
var target_direction : float
var stun_time : int = 0
var health : int = 10
var target_camo_level : int
var weapons_animation_blend := Vector2.ONE
var target_head_rot_off_y : float = 0.0 #rot of head in relation to body rot
var target_world_collide_height : float
var target_world_collide_y : float

func in_standing_state() -> bool:
	return state in [States.STAND, States.WALK, States.RUN, States.PARANOID_WALK]

func in_crouching_state() -> bool:
	return state in [States.CROUCH, States.CROUCH_WALK]

func in_prone_state() -> bool:
	return state in [States.PRONE, States.CRAWL]

func perform_action():
	match queued_action:
		GameActions.GO_STAND:
			match state:
				States.PRONE, States.CRAWL:
					pass
				States.CROUCH, States.CROUCH_WALK:
					pass
		GameActions.GO_CROUCH:
			match state:
				States.WALK, States.RUN, States.STAND, States.PARANOID_WALK:
					pass
				States.PRONE, States.CRAWL:
					pass

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())


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

	# debug
	debug_setup()


func _process(_delta: float) -> void:
	debug_process()
	_outline_mat.albedo_color = _outline_mat.albedo_color.lerp(Color.BLACK, 0.2)
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


func _physics_process(_delta: float) -> void:
	weapons_animation_blend = weapons_animation_blend.lerp(decide_weapon_blend(), 0.2)
	anim.set("parameters/Crouch/blend_position", weapons_animation_blend)
	anim.set("parameters/Stand/blend_position", weapons_animation_blend)
	_eyes.position = _eyes.position.lerp(decide_head_position(), 0.2)
	_eyes.rotation.y = lerpf(_eyes.rotation.y, target_head_rot_off_y, 0.2)
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
	if in_crouching_state():
		target_world_collide_height = 0.666
		target_world_collide_y = 0.35
	if in_prone_state():
		target_world_collide_height = 0.264
		target_world_collide_y = 0.15
	_world_collide.position.y = lerpf(_world_collide.position.y, target_world_collide_y, 0.2)
	(_world_collide.get_shape() as BoxShape3D).size.y = lerpf(
			(_world_collide.get_shape() as BoxShape3D).size.y,
			target_world_collide_height,
			0.2
	)
	if is_multiplayer_authority():
		var move_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		position = position + Vector3(move_dir.x, 0, move_dir.y)


func _agent_clicked(camera: Node, event: InputEvent, position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouse:
		if event.button_mask == MOUSE_BUTTON_MASK_LEFT:
			agent_already_selected = not agent_already_selected
			emit_signal("agent_selected" if agent_already_selected else "agent_deselected", self)
			_outline_mat.albedo_color = Color.AQUA

