class_name AimingIndicator
extends AnimatedSprite3D

signal indicator_placed(indicator)
const CLOSENESS := 2.0

@onready var _game_camera : GameCamera = $"../../World/Camera3D"
@onready var _ray : RayCast3D = $RayCast3D
var referenced_agent : Agent
var ind_set := false

var flat_position : Vector2
var ray_position : Vector3
var position_valid : bool

func _ready() -> void:
	play("aim")


func _game_step(delta):
	if referenced_agent.state != Agent.States.USING_WEAPON:
		if referenced_agent.state == Agent.States.RELOADING_WEAPON:
			return
		if referenced_agent.state != Agent.States.HURT and referenced_agent.in_incapacitated_state():
			play("success")
		else:
			play("fail")


func _on_animation_changed() -> void:
	if not ind_set:
		return
	await animation_finished
	queue_free()


func _check_position() -> bool: #TODO
	# height check
	if global_position.y > 1:
		return false
	# sightline check
	_ray.global_position = referenced_agent.global_position + Vector3.UP * 0.5
	_ray.target_position = (global_position - referenced_agent.global_position) + Vector3.UP * 0.5
	_ray.target_position.y = maxf(_ray.target_position.y, 0.5)
	_ray.force_raycast_update()
	if _ray.get_collider():
		return false
	return true


func _physics_process(delta: float) -> void: #TODO
	if not ind_set:
		flat_position.x = _game_camera.position.x
		flat_position.y = _game_camera.position.z
		ray_position = Vector3(flat_position.x, _game_camera.ground_height + 0.5, flat_position.y)
		#distance clamp
		var ray_to_ag = ray_position - referenced_agent.global_position
		if ray_to_ag.length() > 1:
			var col_norm = ray_to_ag / ray_to_ag.length()
			ray_position = referenced_agent.global_position + col_norm
		global_position = ray_position
		position_valid = _check_position()
	modulate = Color.WHITE if position_valid else Color.RED



func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not ind_set and position_valid:
			ind_set = true
			indicator_placed.emit(self)
