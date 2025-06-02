class_name MovementIndicator
extends AnimatedSprite3D

signal indicator_placed(indicator)
const CLOSENESS := 2.0

@onready var _game_camera : GameCamera = $"../../World/Camera3D"
@onready var _ray_left : RayCast3D = $LeftCast
@onready var _ray_middle : RayCast3D = $MiddleCast
@onready var _ray_right : RayCast3D = $RightCast
@onready var _travel_path : MeshInstance3D = $MeshInstance3D
var referenced_agent : Agent
var queued_action : Array
var ind_set := false

var flat_position : Vector2
var ray_position : Vector3
var position_valid : bool

func _ready() -> void:
	match queued_action[0]:
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


func calculate_travel_dist():
	var arr : PackedVector3Array = referenced_agent.get_position_list(global_position)
	#print(arr)
	var tot = 0.0
	var final : Vector3 = referenced_agent.global_position
	(_travel_path.mesh as ArrayMesh).clear_surfaces()
	var verts = PackedVector3Array()
	var normals = PackedVector3Array()
	var start = referenced_agent.global_position
	$DebugLabel3D.text = ""
	for pos in arr:
		$DebugLabel3D.text += str(pos) + "\n"
		var try_tot = tot + abs(start.distance_to(pos))
		if try_tot <= referenced_agent.movement_dist:
			tot = try_tot
			final = pos
			create_path_rect(start, pos, 0.25, verts, normals)
			start = pos
		else:
			var diff = abs(start.distance_to(pos))/referenced_agent.movement_dist
			var end_clipped = start + (start.direction_to(pos) * diff)
			#print("diff = {0}\nend_clipped = {1}".format([diff, end_clipped]))
			final = end_clipped
			$DebugLabel3D.text += str(final) + " CLIPPED\n"
			create_path_rect(start, end_clipped, 0.25, verts, normals)
			start = pos
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
		var ref_ag_move_dist = referenced_agent.movement_dist
		var ray_to_ag = ray_position - referenced_agent.global_position
		if ray_to_ag.length() > ref_ag_move_dist:
			var col_norm = ray_to_ag / ray_to_ag.length()
			ray_position = referenced_agent.global_position + (col_norm * ref_ag_move_dist)
		global_position = ray_position
		# create movement path and limit actual movement distance
		global_position = calculate_travel_dist()
		#position_valid = _check_position()

	modulate = Color.WHITE if position_valid else Color.RED
	#$DebugLabel3D.text = str(referenced_agent.position.distance_to(position)) + "\n" + str(position)



func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not ind_set and position_valid:
			ind_set = true
			indicator_placed.emit(self)
