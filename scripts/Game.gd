class_name Game
extends Node3D

@export var agent_scene : PackedScene
var hud_agent_small_scene = preload("res://scenes/hud_agent_small.tscn")

var server_agents : Dictionary
var client_agents : Dictionary

var selected_agent : Agent = null
var game_map : GameMap

func _ready():
	# Preconfigure game.
	server_agents = {}
	client_agents = {}
	#Lobby.player_loaded.rpc_id(1) # Tell the server that this peer has loaded.

# Called only on the server.
func start_game():
	# All peers are ready to receive RPCs in this scene.
	ping.rpc()
	#server_populate_agent_dictionaries()
	#send_populated_dictionaries.rpc_id(other_player)
	pass

func create_sound_effect() -> void: #TODO
	pass

func server_populate_agent_dictionaries(): #TODO
	var spawn_ind = 0
	for agent_ind in GameSettings.selected_agents:
		create_agent.rpc(1, Lobby.players[1].agents[agent_ind], game_map.server_agent_spawns[spawn_ind])
		server_agents[get_node("Agents/1_{0}".format([Lobby.players[1].agents[agent_ind].name]))] = {
			small_hud = hud_agent_small_scene.instantiate()
		}

	pass

@rpc()
func ping():
	print("pong!")

#func _add_player(id = 1):
	#var new_player = player_scene.instantiate()
	#new_player.name = str(id)
	#call_deferred("add_child", new_player)

@rpc("authority", "call_local", "reliable")
func create_agent(player_id, agent_stats, spawn_details): #TODO
	var new_agent = Agent.new()
	new_agent.name = str(player_id) + "_" + str(agent_stats.name)
	new_agent.agent_selected.connect(_hud_agent_details_actions)
	new_agent.agent_deselected
	new_agent.action_chosen
	new_agent.action_completed
	new_agent.action_interrupted
	new_agent.agent_died

	pass

func _hud_agent_details_actions(agent : Agent): #TODO

	pass
