class_name GameItem
extends Node

var uses_total : int
var uses_left : int

func _ready():
	uses_left = uses_total

func item_subroutine() -> void:
	uses_left -= 1
	pass

func use_item() -> bool:
	if uses_left < 1:
		return false
	else:
		item_subroutine()
		return true
