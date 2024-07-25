class_name ToastMessage
extends Control

@onready var _text_node : Label = $Label
@onready var _color_bg : ColorRect = $Label/ColorRect
@onready var _audio : AudioStreamPlayer = $AudioStreamPlayer
@export var text : String
@export var color : Color
var progress : float = 0.0

func _ready():
	_text_node.text = "".rpad(text.length(), "_")
	_color_bg.color = color
	var twe = create_tween()
	twe.set_parallel()
	twe.tween_property(self, "progress", 1.0, 1.0).from(0.0)
	twe.tween_property(_color_bg, "size:x", 553, 1.0).from(0)


func _physics_process(_delta: float) -> void:
	_text_node.text = underscore_to_text(text, progress)


func underscore_to_text(text : String, underscore_percentage : float):
	if underscore_percentage < 1.00:
		_audio.play()
	return (
		text.substr(
			0,
			int(float(text.length()) * underscore_percentage)
			)
		+ "".rpad(
			ceil(float(text.length()) * (1 - underscore_percentage)),
			"_")
		)


func _on_persist_time_timeout() -> void:
	var twe = create_tween()
	twe.tween_property(_text_node, "scale:y", 0.0, 0.5).from(1.0)
	twe.finished.connect(queue_free)
