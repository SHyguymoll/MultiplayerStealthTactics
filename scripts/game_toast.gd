class_name ToastMessage
extends Label

@onready var _color_bg : ColorRect = $ColorRect
@onready var _audio : AudioStreamPlayer = $AudioStreamPlayer
@export var input_text : String
@export var color : Color
var progress : float = 0.0

func _ready():
	text = "".rpad(input_text.length(), "_")
	_color_bg.color = color
	var twe = create_tween()
	twe.set_parallel()
	twe.tween_property(self, "progress", 1.0, 1.0).from(0.0)
	twe.tween_property(_color_bg, "size:x", 553, 1.0).from(0)


func _physics_process(_delta: float) -> void:
	text = underscore_to_text(input_text, progress)


func underscore_to_text(given_text : String, underscore_percentage : float):
	if underscore_percentage < 1.00:
		_audio.play()
	return (
		given_text.substr(
			0,
			int(float(input_text.length()) * underscore_percentage)
			)
		+ "".rpad(
			ceil(float(given_text.length()) * (1 - underscore_percentage)),
			"_")
		)


func _on_persist_time_timeout() -> void:
	var twe = create_tween()
	twe.tween_property(self, "scale:y", 0.0, 0.5).from(1.0)
	twe.finished.connect(queue_free)
