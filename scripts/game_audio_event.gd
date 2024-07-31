class_name GameAudioEvent
extends Node3D

@onready var _area_shape : CollisionShape3D = $Area3D/CollisionShape3D
@onready var _audio_node : AudioStreamPlayer = $AudioStreamPlayer

var player_id : int
var max_lifetime : int
var lifetime : int
var radius : float
var max_radius : float
var selected_audio : String

var heard := false

func _ready():
	_area_shape.shape = CylinderShape3D.new()
	_area_shape.shape.height = 7.0
	_area_shape.shape.radius = 0.001
	_audio_node.stream = GameRefs.AUDIO.get(selected_audio, null)
	if player_id == multiplayer.get_unique_id():
		play_sound()


func update():
	lifetime = max(lifetime - 1, 0)
	radius = lerpf(0.001, max_radius, float(max_lifetime - lifetime)/float(max_lifetime))
	_area_shape.shape.radius = radius
	$Sprite3D.scale = Vector3(radius, radius, radius)
	if lifetime == 0:
		_area_shape.disabled = true
		if not _audio_node.playing:
			queue_free()


func play_sound():
	_audio_node.play()
	heard = true
