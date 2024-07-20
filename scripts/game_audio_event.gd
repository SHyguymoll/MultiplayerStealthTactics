class_name GameAudioEvent
extends Node3D

@onready var _area_shape : CollisionShape3D = $Area3D/CollisionShape3D
@onready var _audio_node : AudioStreamPlayer = $AudioStreamPlayer

var player_id : int
var max_lifetime : int
var lifetime : int
var radius : float
var min_radius : float
var max_radius : float
var selected_audio : String

var heard := false

func _ready():
	_area_shape.shape = CylinderShape3D.new()
	_area_shape.shape.height = 7.0
	_area_shape.shape.radius = min_radius
	_audio_node.stream = GameRefs.AUDIO.get(selected_audio, null)

func update_radius():
	radius = lerpf(min_radius, max_radius, float(max_lifetime - lifetime)/max_lifetime)
	_area_shape.shape.radius = radius

func play_sound():
	_audio_node.play()
	heard = true
