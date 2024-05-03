class_name Agent
extends Node2D

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

@onready var _animate : AnimationPlayer = $AnimationPlayer

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
	STUNNED, DEAD,
}
var state : States = States.STAND

var target_position : Vector2
var target_direction : float

var target_camo_level : int

func perform_action():
	match queued_action:
		GameActions.GO_STAND:
			match state:
				States.PRONE, States.CRAWL:
					_animate.queue("CrouchFromProne")
					_animate.queue("StandFromCrouch")
					_animate.queue("Idle")
				States.CROUCH, States.CROUCH_WALK:
					_animate.queue("StandFromCrouch")
					_animate.queue("Idle")
