@tool
class_name ExfilZone
extends Area3D

const SERVER_COL_VAL = 8
const CLIENT_COL_VAL = 16

const EXFIL_SHADER = preload("res://assets/models/materials/exfil_zone.tres")

const CHECKERBOARD_SIZE = 4.0

const SERV_COLOR = Color(0x8a2be2FF)
const CLIE_COLOR = Color(0x004700FF)
const ALL_COLOR = Color(0x808080FF)
const NONE_COLOR = Color(0x000000FF)

@export var osc_rate := 1.0

@export var server_can_exfil : bool
@export var client_can_exfil : bool

@export var exfil_enabled : bool

@onready var collision_zone := $CollisionShape3D
@onready var rendered_shape := $MeshInstance3D
@export var collision_shape : Vector3

func _ready() -> void:
	(collision_zone.shape as BoxShape3D).size = collision_shape
	collision_layer = (SERVER_COL_VAL * int(server_can_exfil)) + (CLIENT_COL_VAL * int(client_can_exfil))
	collision_mask = (SERVER_COL_VAL * int(server_can_exfil)) + (CLIENT_COL_VAL * int(client_can_exfil))

	rendered_shape.mesh = PlaneMesh.new()
	(rendered_shape.mesh as PlaneMesh).material = ShaderMaterial.new()
	((rendered_shape.mesh as PlaneMesh).material as ShaderMaterial).shader = EXFIL_SHADER
	(rendered_shape.mesh as PlaneMesh).size = Vector2(collision_shape.x, collision_shape.z)
	(rendered_shape.mesh as PlaneMesh).subdivide_width = max(0, int(collision_shape.x * 8))
	(rendered_shape.mesh as PlaneMesh).subdivide_depth = max(0, int(collision_shape.z * 8))
	((rendered_shape.mesh as PlaneMesh).material as ShaderMaterial).set_shader_parameter(&"color",
		ALL_COLOR if server_can_exfil and client_can_exfil else SERV_COLOR if server_can_exfil else
			CLIE_COLOR if client_can_exfil else NONE_COLOR)
	((rendered_shape.mesh as PlaneMesh).material as ShaderMaterial).set_shader_parameter(&"oscillation_rate", osc_rate)
	((rendered_shape.mesh as PlaneMesh).material as ShaderMaterial).set_shader_parameter(&"col_shape", Vector2(collision_shape.x, collision_shape.z))
	((rendered_shape.mesh as PlaneMesh).material as ShaderMaterial).set_shader_parameter(&"checkerboard_size", CHECKERBOARD_SIZE)
	((rendered_shape.mesh as PlaneMesh).material as ShaderMaterial).set_shader_parameter(&"checkerboard_gap", 0.0 if exfil_enabled else 0.5)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		(collision_zone.shape as BoxShape3D).size = collision_shape
		(rendered_shape.mesh as PlaneMesh).size = Vector2(collision_shape.x, collision_shape.z)
		(rendered_shape.mesh as PlaneMesh).subdivide_width = max(0, int(collision_shape.x * 8))
		(rendered_shape.mesh as PlaneMesh).subdivide_depth = max(0, int(collision_shape.z * 8))
		collision_layer = (SERVER_COL_VAL * int(server_can_exfil)) + (CLIENT_COL_VAL * int(client_can_exfil))
		collision_mask = (SERVER_COL_VAL * int(server_can_exfil)) + (CLIENT_COL_VAL * int(client_can_exfil))

		((rendered_shape.mesh as PlaneMesh).material as ShaderMaterial).set_shader_parameter(&"color",
			ALL_COLOR if server_can_exfil and client_can_exfil else SERV_COLOR if server_can_exfil else
				CLIE_COLOR if client_can_exfil else NONE_COLOR)
		((rendered_shape.mesh as PlaneMesh).material as ShaderMaterial).set_shader_parameter(&"oscillation_rate", osc_rate)
		((rendered_shape.mesh as PlaneMesh).material as ShaderMaterial).set_shader_parameter(&"col_shape", Vector2(collision_shape.x, collision_shape.z))
		((rendered_shape.mesh as PlaneMesh).material as ShaderMaterial).set_shader_parameter(&"checkerboard_gap", 0.0 if exfil_enabled else 0.5)
