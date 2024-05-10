class_name Game
extends Node3D

var peer = ENetMultiplayerPeer.new()
@export var agent_scene : PackedScene

var server_agents : Array[Agent]
var client_agents : Array[Agent]

var selected_agent : Agent = null

func _ready():
	# Preconfigure game.
	server_agents = []
	client_agents = []
	#Lobby.player_loaded.rpc_id(1) # Tell the server that this peer has loaded.

# Called only on the server.
func start_game():
	# All peers are ready to receive RPCs in this scene.

	pass

func create_sound_effect() -> void:
	pass

@rpc()
func ping():
	print("pong!")

#func _add_player(id = 1):
	#var new_player = player_scene.instantiate()
	#new_player.name = str(id)
	#call_deferred("add_child", new_player)

@rpc("authority", "call_local", "reliable")
func spawn_agent(player_id, agent_stats):
	var new_agent = Agent.new()
	new_agent.agent_selected.connect(_show_agent_state_actions)
	pass

func _show_agent_state_actions(agent : Agent):

	pass
