extends Node

@export var game : Game

func _ready() -> void:
	if not multiplayer.is_server():
		queue_free()
