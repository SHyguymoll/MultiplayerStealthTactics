class_name MovementIndicator
extends AnimatedSprite3D

signal indicator_placed(indicator)
const CLOSENESS := 2.0

@onready var _game_camera : GameCamera = $"../../World/Camera3D"
@onready var _ray_middle : RayCast3D = $MiddleCast
@onready var _travel_path : MeshInstance3D = $MeshInstance3D
var referenced_agent : Agent
var queued_action : Array
var ind_set := false

var flat_position : Vector2
var ray_position : Vector3
var position_valid : bool

const MASK_STAND = 128
const MASK_CROUCH = 2
const MASK_PRONE = 4

func _ready() -> void:
	$DebugLabel3D.text = ""
	match queued_action[0]:
		Agent.GameActions.WALK_TO_POS:
			update_detection(MASK_STAND)
			play("walk")
		Agent.GameActions.RUN_TO_POS:
			update_detection(MASK_STAND)
			play("run")
		Agent.GameActions.CROUCH_WALK_TO_POS:
			update_detection(MASK_CROUCH)
			play("crouch_walk")
		Agent.GameActions.CRAWL_TO_POS:
			update_detection(MASK_PRONE)
			play("crawl")


func update_detection(new_mask : int):
	_ray_middle.collision_mask = new_mask


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

	_ray_middle.force_raycast_update()
	return _ray_middle.is_colliding()


func create_path_rect(start : Vector3, end : Vector3, width : float, vert_arr : PackedVector3Array, norm_arr : PackedVector3Array):
	var angle_perpendicular = start.direction_to(end).rotated(Vector3.DOWN, PI/2).normalized()
	var point_1 = start - (angle_perpendicular * (width / 2.0))
	var point_2 = end - (angle_perpendicular * (width / 2.0))
	var point_3 = end + (angle_perpendicular * (width / 2.0))
	var point_4 = start + (angle_perpendicular * (width / 2.0))
	vert_arr.push_back(point_1)
	norm_arr.push_back(Vector3.UP)
	vert_arr.push_back(point_2)
	norm_arr.push_back(Vector3.UP)
	vert_arr.push_back(point_3)
	norm_arr.push_back(Vector3.UP)
	vert_arr.push_back(point_1)
	norm_arr.push_back(Vector3.UP)
	vert_arr.push_back(point_3)
	norm_arr.push_back(Vector3.UP)
	vert_arr.push_back(point_4)
	norm_arr.push_back(Vector3.UP)


func create_path_corner(start : Vector3, last_angle : Vector3, now_angle : Vector3, width : float, vert_arr : PackedVector3Array, norm_arr : PackedVector3Array):
	var cross = last_angle.cross(now_angle)
	var last_perp = last_angle.rotated(Vector3.DOWN, PI/2).normalized()
	var now_perp = now_angle.rotated(Vector3.DOWN, PI/2).normalized()
	var point_1 = start
	var point_2 = Vector3.ZERO
	var point_3 = Vector3.ZERO
	if cross.y > 0:
		point_2 = start + (now_perp * (width / 2.0))
		point_3 = start + (last_perp * (width / 2.0))
	else:
		point_2 = start - (last_perp * (width / 2.0))
		point_3 = start - (now_perp * (width / 2.0))
	vert_arr.push_back(point_1)
	norm_arr.push_back(Vector3.UP)
	vert_arr.push_back(point_2)
	norm_arr.push_back(Vector3.UP)
	vert_arr.push_back(point_3)
	norm_arr.push_back(Vector3.UP)


func calculate_travel_dist():
	var arr : PackedVector3Array = referenced_agent.get_position_list(global_position)
	#print(arr)
	var final : Vector3 = referenced_agent.global_position
	(_travel_path.mesh as ArrayMesh).clear_surfaces()
	var verts = PackedVector3Array()
	var normals = PackedVector3Array()
	var start = referenced_agent.global_position
	var max_travel = referenced_agent.movement_dist
	var last_ang = Vector3.ZERO
	#$DebugLabel3D.text = str(max_travel)
	for pos in arr:
		var step_len = abs(start.distance_to(pos))
		var step_ang = start.direction_to(pos)
		if step_len <= max_travel:
			max_travel -= step_len
			#$DebugLabel3D.text += "\n" + str(max_travel)
			final = pos
			if last_ang != Vector3.ZERO and not is_zero_approx(step_ang.dot(last_ang) - 1.0):
				create_path_corner(start, last_ang, step_ang, 0.25, verts, normals)
			create_path_rect(start, pos, 0.25, verts, normals)
			start = pos
			last_ang = step_ang
		else:
			var diff = abs(start.distance_to(pos))
			var end_clipped = start + (start.direction_to(pos) * diff)
			final = end_clipped
			#$DebugLabel3D.text += "\n0, CLIPPED"
			if last_ang != Vector3.ZERO and not is_zero_approx(step_ang.dot(last_ang) - 1.0):
				create_path_corner(start, last_ang, step_ang, 0.25, verts, normals)
			create_path_rect(start, end_clipped, 0.25, verts, normals)
			start = pos
			last_ang = step_ang
			break
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	surface_array[Mesh.ARRAY_VERTEX] = verts
	surface_array[Mesh.ARRAY_NORMAL] = normals
	(_travel_path.mesh as ArrayMesh).add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	return final

func _physics_process(_d: float) -> void:
	if not ind_set:
		if _game_camera.ground_detected():
			flat_position.x = _game_camera.position.x
			flat_position.y = _game_camera.position.z
			ray_position = Vector3(flat_position.x, _game_camera.ground_height, flat_position.y)
		# simple distance clamp
		#var ref_ag_move_dist = referenced_agent.movement_dist
		#var ray_to_ag = ray_position - referenced_agent.global_position
		#if ray_to_ag.length() > ref_ag_move_dist:
			#var col_norm = ray_to_ag / ray_to_ag.length()
			#ray_position = referenced_agent.global_position + (col_norm * ref_ag_move_dist)
		#global_position = ray_position
		# create movement path and limit actual movement distance
		global_position = calculate_travel_dist()
		position_valid = _check_position()

	modulate = Color.WHITE if position_valid else Color.RED
	#$DebugLabel3D.text = str(referenced_agent.position.distance_to(position)) + "\n" + str(position)



func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not ind_set and position_valid:
			ind_set = true
			indicator_placed.emit(self)
