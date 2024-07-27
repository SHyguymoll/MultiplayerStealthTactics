extends RayCast3D

var source : Node3D
var sink : Node3D

func _physics_process(_d: float) -> void:
	global_position = source.global_position
	target_position = sink.global_position - source.global_position
