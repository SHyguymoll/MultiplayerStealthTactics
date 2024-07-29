class_name Smoke
extends MeshInstance3D

@onready var mesh_shape : SphereMesh = mesh
@onready var collision : CylinderShape3D = $Area3D/CollisionShape3D.shape
@onready var col_area : Area3D = $Area3D
@export var smoke_rad_curve : Curve
@export var smoke_hei_curve : Curve
@export var trans_curve : Curve

var lifetime := 0

func _ready() -> void:
	mesh_shape.radius = 0.001
	mesh_shape.height = 0.001
	smoke_rad_curve.bake()
	smoke_hei_curve.bake()
	trans_curve.bake()
	transparency = 1.0

func _tick():
	mesh_shape.radius = remap(smoke_rad_curve.sample(float(lifetime)/200), 0.0, 1.0, 0.001, 5.0)
	mesh_shape.height = remap(smoke_hei_curve.sample(float(lifetime)/200), 0.0, 1.0, 0.001, 3.5)
	transparency = trans_curve.sample(float(lifetime)/200)
	collision.radius = max(mesh_shape.radius - 0.25, 0.001)
	lifetime += 1
