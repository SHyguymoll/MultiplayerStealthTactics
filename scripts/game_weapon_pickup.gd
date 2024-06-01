extends Node3D

var position_y = 0

func _physics_process(delta: float) -> void:
	for weapon_mesh in get_children():
		weapon_mesh.rotation.y += delta * 3
		position_y = fmod(position_y + delta*2, PI*2)
		weapon_mesh.position.y = sin(position_y)/16 + 0.5
