class_name AgentSelector
extends VBoxContainer

signal agent_selected(name : String)
signal selector_removed(agent_selected : bool)

var add_agent_texture : Texture2D = preload("res://assets/sprites/SelectAnAgent.png")
var agent_selected_texture : Texture2D = preload("res://assets/sprites/AgentInfoBackground.png")
var next_selector : AgentSelector

@onready var opt_but : OptionButton = $OptionButton
@onready var _tex_rect : TextureRect = $TextureRect

var selection_made := false

func _ready() -> void:
	_tex_rect.texture = add_agent_texture
	for agent in Lobby.player_info.agents:
		opt_but.add_item(agent.name)
	opt_but.selected = 0
	opt_but.disabled = true


func _on_option_button_item_selected(index: int) -> void:
	if index == 0:
		return
	agent_selected.emit(opt_but.get_item_text(index))
	_tex_rect.texture = agent_selected_texture


func enable_opt_button(_agent_name):
	opt_but.disabled = false


func _on_button_pressed() -> void:
	selector_removed.emit(selection_made)
	opt_but.selected = 0
	opt_but.disabled = false
