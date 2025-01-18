@tool
class_name ExfilZone
extends Area3D

const SERVER_COL_VAL = 8
const CLIENT_COL_VAL = 16

const SERVER_COL = Color.BLUE_VIOLET
const CLIENT_COL = Color.DARK_GREEN

@export var server_can_exfil : bool
@export var client_can_exfil : bool

@export var osc_rate := 1.0

@onready var collision_zone := $CollisionShape3D
@onready var rendered_shape := $MeshInstance3D
@export var collision_shape : Vector3

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		(collision_zone.shape as BoxShape3D).size = collision_shape
		(rendered_shape.mesh as PlaneMesh).size = Vector2(collision_shape.x, collision_shape.z)
		(rendered_shape.mesh as PlaneMesh).subdivide_width = max(0, int(collision_shape.x * 8))
		(rendered_shape.mesh as PlaneMesh).subdivide_depth = max(0, int(collision_shape.z * 8))
		((rendered_shape.mesh as PlaneMesh).material as ShaderMaterial).set_shader_parameter(&"col_shape", Vector2(collision_shape.x, collision_shape.z))

		collision_layer = (SERVER_COL_VAL * int(server_can_exfil)) + (CLIENT_COL_VAL * int(client_can_exfil))
		collision_mask = (SERVER_COL_VAL * int(server_can_exfil)) + (CLIENT_COL_VAL * int(client_can_exfil))
		((rendered_shape.mesh as PlaneMesh).material as ShaderMaterial).set_shader_parameter(&"color", SERVER_COL)
		((rendered_shape.mesh as PlaneMesh).material as ShaderMaterial).set_shader_parameter(&"oscillation_rate", osc_rate)
