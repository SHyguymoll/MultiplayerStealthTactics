class_name GameAudioEvent
extends Sprite3D


@onready var _audio_node : AudioStreamPlayer = $AudioStreamPlayer

var max_lifetime : int
var lifetime : int
var radius : float
var min_radius : float
var selected_audio : String

func _ready():
	_area_shape.shape = CylinderShape3D.new()
	_area_shape.shape.height = 7.0
	_audio_node.stream = AUDIOS.get(selected_audio, null)

func update_radius():
	radius = lerpf(min_radius, max_radius, float(max_lifetime - lifetime)/max_lifetime)
	_area_shape.shape.radius = radius
