extends Camera3D

var drag_enabled := false
var last_position := Vector2.ZERO
var final_position := Vector2.ZERO
var cutscene_mode := false
var sensitivity := 10.5
var quickness := 0.3
var fov_target := 75.0

func _ready() -> void:
	position = Vector3(0, 15, 0)
	h_offset = 0
	v_offset = 0

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			print("PRESSED" if event.pressed else "UNPRESSED")
			drag_enabled = event.pressed
			if event.pressed:
				last_position = event.position
		#if event.button_index == MOUSE_BUTTON_LEFT:
			#explode(2, 10)
	elif event is InputEventMouseMotion and drag_enabled and not cutscene_mode:
		final_position += (last_position - event.position)
		last_position = event.position

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("fov_change"):
		match fov_target:
			75.0:
				fov_target = 45.0
			45.0:
				fov_target = 20.0
			_:
				fov_target = 75.0
	position.x = lerpf(position.x, (final_position.x * sensitivity/get_viewport().size.x), quickness)
	position.z = lerpf(position.z, (final_position.y * sensitivity/get_viewport().size.y), quickness)
	fov = lerpf(fov, fov_target, quickness)

	#$/root/Game/Label.text = str(position, "\n", last_position, "\n", final_position, "\n", h_offset, "\n", v_offset)
# (mouse_offset.x/get_viewport().size.x)
func explode(force: float, shakes : int):
	for shake in range(1, shakes+1):
		h_offset = (randf() - 0.5)*force*(shakes/shake)
		v_offset = (randf() - 0.5)*force*(shakes/shake)
		await get_tree().create_timer(0.01).timeout
	h_offset = 0
	v_offset = 0
