class_name GamePopup
extends Sprite3D

@onready var _detect_area : Area3D

func disappear():
	var twe = create_tween()
	twe.set_parallel(true)
	twe.set_trans(Tween.TRANS_CUBIC)
	twe.tween_property(self, "pixel_size", 0.1, 0.25).from(0.01)
	twe.tween_property(self, "modulate:a", 0, 0.25).from(1)
	twe.finished.connect(queue_free)
