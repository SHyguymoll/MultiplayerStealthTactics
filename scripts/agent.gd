class_name Agent
extends Node3D

signal action_completed
signal action_interrupted
signal agent_died
signal action_chosen
signal agent_selected
signal agent_deselected

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

var held_items : Array[GameItem] = [null] #max length should be 5, including no item (null)
var held_weapons : Array[GameWeapon] = [null] #max length should be 4, including no item (null)

var selected_item : int = 0 #index for item
var selected_weapon : int = 0 #index for weapon

var player_id : int #id of player who brought the agent

@export var skin_texture : String

@onready var anim : AnimationTree = $AnimationTree
@onready var _mesh : MeshInstance3D = $Agent/game_rig/Skeleton3D/Mesh
@onready var _custom_skin_mat : StandardMaterial3D
@onready var _eyes : ShapeCast3D = $Eyes
@onready var _eye_cone = _eyes.shape as ConvexPolygonShape3D
@onready var _ears : ShapeCast3D = $Ears
@onready var _ear_cylinder = _ears.shape as CylinderShape3D
@onready var _body : Area3D = $Body


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
var target_weapons_animation := Vector2.ONE
var head_rot_off_y : float = 0.0 #rot of head in relation to body rot

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
	$DebugValues/DuringGame/HeadScroll.min_value = -75
	$DebugValues/DuringGame/HeadScroll.max_value = 75
	$DebugValues/DuringGame/HeadScroll.value = 0
	$DebugValues/DuringGame/HeadScroll.step = 1


func debug_process():
	$DebugValues/DuringGame/StateLabel.text = States.keys()[state]
	state = $DebugValues/DuringGame/StateScroll.value
	view_dist = $DebugValues/GameSetup/EyeLengthScroll.value
	view_across = $DebugValues/GameSetup/EyeAcrossScroll.value
	hearing_dist = $DebugValues/GameSetup/EarScroll.value

	eye_strength = $DebugValues/DuringGame/EyeScroll.value
	ear_strength = $DebugValues/DuringGame/EarScroll.value
	_eyes.rotation_degrees.y = $DebugValues/DuringGame/HeadScroll.value
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
	# debug
	debug_setup()


func _process(_delta: float) -> void:
	debug_process()
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


func _physics_process(_delta: float) -> void:
	anim.set("parameters/Crouch/blend_position", target_weapons_animation)
	anim.set("parameters/Stand/blend_position", target_weapons_animation)
	_eyes.position = _eyes.position.lerp(decide_head_position(), 0.2)
	_eyes.rotation.y = head_rot_off_y
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
	if is_multiplayer_authority():
		var move_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		position = position + Vector3(move_dir.x, 0, move_dir.y)
