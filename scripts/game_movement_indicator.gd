class_name MovementIndicator
extends AnimatedSprite3D

signal indicator_placed(indicator)
const CLOSENESS := 2.0

@onready var _game_camera : GameCamera = $"../../World/Camera3D"
@onready var _ray_left : RayCast3D = $LeftCast
@onready var _ray_middle : RayCast3D = $MiddleCast
@onready var _ray_right : RayCast3D = $RightCast
var referenced_agent : Agent
var ind_set := false

var flat_position : Vector2
var ray_position : Vector3
var position_valid : bool

func _ready() -> void:
	match referenced_agent.queued_action[0]:
		Agent.GameActions.WALK_TO_POS:
			play("walk")
		Agent.GameActions.RUN_TO_POS:
			play("run")
		Agent.GameActions.CROUCH_WALK_TO_POS:
			play("crouch_walk")
		Agent.GameActions.CRAWL_TO_POS:
			play("crawl")


func _succeed():
	play("movement_end_success")


func _fail():
	play("movement_end_fail")


func _neutral():
	play("movement_end_neutral")


func _on_animation_changed() -> void:
	if not ind_set:
		return
	await animation_finished
	queue_free()


func _check_position() -> bool:
	# height check
	if global_position.y > 1:
		return false
	# sightline check
	var center_start = referenced_agent.global_position + Vector3.UP * 0.1
	var center_target = (global_position - referenced_agent.global_position) + Vector3.UP * 0.1
	center_target.y = maxf(center_target.y, 0.5)
	var final_col_mask = 1 + 64 + 128
	if referenced_agent.in_prone_state():
		final_col_mask = 1
	elif referenced_agent.in_crouching_state():
		final_col_mask = 1 + 64

	var angled_left = (center_target.normalized() * 0.3).rotated(
					Vector3.UP, deg_to_rad(-90))
	var angled_right = (center_target.normalized() * 0.3).rotated(
					Vector3.UP, deg_to_rad(90))

	_ray_left.global_position = center_start + angled_left
	_ray_middle.global_position = center_start
	_ray_right.global_position = center_start + angled_right
	_ray_left.target_position = center_target
	_ray_middle.target_position = center_target
	_ray_right.target_position = center_target
	_ray_left.collision_mask = final_col_mask
	_ray_middle.collision_mask = final_col_mask
	_ray_right.collision_mask = final_col_mask
	_ray_left.force_raycast_update()
	_ray_middle.force_raycast_update()
	_ray_right.force_raycast_update()
	if _ray_left.get_collider() or _ray_middle.get_collider() or _ray_right.get_collider():
		return false
	return true


func _physics_process(delta: float) -> void:
	if not ind_set:
		flat_position.x = _game_camera.position.x
		flat_position.y = _game_camera.position.z
		ray_position = Vector3(flat_position.x, _game_camera.ground_height, flat_position.y)
		#distance clamp
		var ref_ag_move_dist = referenced_agent.movement_dist
		var ray_to_ag = ray_position - referenced_agent.global_position
		if ray_to_ag.length() > ref_ag_move_dist:
			var col_norm = ray_to_ag / ray_to_ag.length()
			ray_position = referenced_agent.global_position + (col_norm * ref_ag_move_dist)
		global_position = ray_position
		position_valid = _check_position()
	modulate = Color.WHITE if position_valid else Color.RED
	#$DebugLabel3D.text = str(referenced_agent.position.distance_to(position)) + "\n" + str(position)



func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not ind_set and position_valid:
			ind_set = true
			indicator_placed.emit(self)
