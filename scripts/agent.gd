class_name Agent
extends Node3D

signal action_completed
signal action_interrupted
signal agent_died

var view_dist : float #length of vision cone
var view_arc : float #arc of vision cone
var view_direction : float #radian rotation of view in relation to body rotation
var eye_strength : float #multiplier applied to vision cone in relation to view target distance

var hearing_dist : int #distance of furthest possibly heard audio event

var movement_dist : int #distance of furthest possible movement in tiles per turn
var movement_speed : float #maximum movement speed per turn

var camo_level : int #bounded from 0 to 100

var weapon_accuracy : float #bounded from 0.00 to 1.00

var held_items : Array[GameItem] = [null] #max length should be 5, including no item (null)
var held_weapons : Array[GameWeapon] = [null] #max length should be 4, including no item (null)

var selected_item : int = 0 #index for item
var selected_weapon : int = 0 #index for weapon

@export var looping_animations : Array[StringName]
@onready var anim : AnimationTree = $AnimationTree

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
var health : int
var target_camo_level : int
var target_weapons_animation := Vector2.ONE
var head_rot_off_z : float = 0.0

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

func _ready() -> void:
	$HBoxContainer/HScrollBar.min_value = 0
	$HBoxContainer/HScrollBar.max_value = len(States.keys()) - 1
	$HBoxContainer/HScrollBar.value = 0
	$HBoxContainer/HScrollBar.step = 1

func _process(delta: float) -> void:
	$HBoxContainer/Label.text == States.keys()[state]
	state = $HBoxContainer/HScrollBar.value

func _physics_process(delta: float) -> void:
	anim.set("parameters/Crouch/blend_position", target_weapons_animation)
	anim.set("parameters/Stand/blend_position", target_weapons_animation)
	if is_multiplayer_authority():
		var move_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		position = position + Vector3(move_dir.x, 0, move_dir.y)
