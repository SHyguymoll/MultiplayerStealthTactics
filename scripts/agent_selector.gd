class_name AgentSelector
extends Area2D

var referenced_agent : Agent

signal agent_selected(selector : AgentSelector)

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouse and event.button_mask == MOUSE_BUTTON_MASK_LEFT:
		agent_selected.emit(self)
