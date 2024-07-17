class_name AimingIndicator
extends RayCast3D

signal indicator_placed(indicator)
const CLOSENESS := 2.0

@onready var _game_camera : GameCamera = $"../../World/Camera3D"
@onready var _indicator : AnimatedSprite3D = $GameMovementIndicator
var referenced_agent : Agent
var ind_set := false


func _ready() -> void:
	_indicator.play("aim")
	global_position = referenced_agent.global_position + Vector3.UP * (_game_camera.ground_height + 0.5)


func _succeed():
	_indicator.play("success")


func _neutral():
	_indicator.play("neutral")


func _fail():
	_indicator.play("fail")


func _on_animation_changed() -> void:
	if not ind_set:
		return
	await _indicator.animation_finished
	queue_free()


func _physics_process(delta: float) -> void: #TODO
	if not ind_set:
		var ray_len = 1000
		if GameRefs.compare_wep_type(referenced_agent, GameRefs.WeaponTypes.CQC):
			ray_len = 1
		var final_position = Vector2(
			(_game_camera.position.x - referenced_agent.global_position.x),
			(_game_camera.position.z - referenced_agent.global_position.z),
		).normalized() #* ray_len
		if final_position.length() == 0:
			final_position = Vector2.ONE
		target_position.x = final_position.x
		target_position.y = 0
		target_position.z = final_position.y
		target_position = target_position.normalized() * ray_len
		force_raycast_update()
		if get_collider():
			_indicator.global_position = get_collision_point()
		else:
			_indicator.global_position = Vector3(global_position.x + target_position.x, global_position.y, global_position.z + target_position.z)

		match referenced_agent.action_done:
			Agent.ActionDoneness.SUCCESS:
				_succeed()
			Agent.ActionDoneness.FAIL:
				_fail()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not ind_set:
			ind_set = true
			indicator_placed.emit(self)
