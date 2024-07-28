class_name GamePopup
extends Sprite3D

func disappear():
	var twe = create_tween()
	twe.set_parallel(true)
	twe.set_trans(Tween.TRANS_QUAD)
	twe.tween_property(self, "pixel_size", 0.05, 0.5).from(0.01)
	twe.tween_property(self, "modulate", Color.TRANSPARENT, 0.6).from(Color.WHITE)
	twe.finished.connect(queue_free)
