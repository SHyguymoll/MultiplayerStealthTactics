class_name AgentSelector
extends VBoxContainer

signal agent_selected(name : String)
signal selector_removed(agent_selected : bool)

var add_agent_texture : Texture2D = preload("res://assets/sprites/SelectAnAgent.png")
var agent_selected_texture : Texture2D = preload("res://assets/sprites/AgentInfoBackground.png")

@onready var _opt_but : OptionButton = $OptionButton
@onready var _tex_rect : TextureRect = $TextureRect

var selection_made := false

func _ready() -> void:
	_tex_rect.texture = add_agent_texture
	for agent in Lobby.player_info.agents:
		_opt_but.add_item(agent.name)


func _on_option_button_item_selected(index: int) -> void:
	agent_selected.emit(_opt_but.get_item_text(index))
	_opt_but.disabled = true
	_tex_rect.texture = agent_selected_texture


func _on_button_pressed() -> void:
	selector_removed.emit(selection_made)
	queue_free()
	pass # Replace with function body.
