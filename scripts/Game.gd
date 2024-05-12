class_name Game
extends Node3D

@export var agent_scene : PackedScene
var hud_agent_small_scene = preload("res://scenes/hud_agent_small.tscn")

var server_agents : Dictionary
var client_agents : Dictionary

var selected_agent : Agent = null
var game_map : GameMap

@onready var _quick_views : HBoxContainer = $HUDBase/QuickViews

func _ready():
	# Preconfigure game.
	server_agents = {}
	client_agents = {}
	multiplayer.multiplayer_peer = Lobby.multiplayer.multiplayer_peer
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
		create_agent.rpc(
				1,
				Lobby.players[1].agents[agent_ind],
				game_map.server_agent_spawns[spawn_ind])
		spawn_ind += 1
	spawn_ind = 0
	for agent_ind in GameSettings.client_selected_agents:
		create_agent.rpc(
				GameSettings.server_client_id,
				Lobby.players[GameSettings.server_client_id].agents[agent_ind],
				game_map.client_agent_spawns[spawn_ind])
	pass

@rpc("call_local")
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

	if player_id == 1:
		server_agents[new_agent] = {}
		if multiplayer.multiplayer_peer.get_unique_id() == player_id:
			var new_quick : HUDAgentSmall = hud_agent_small_scene.instantiate()
			new_quick.update_state("active")
			new_quick.update_item("none")
			new_quick.update_weapon("none")
			new_quick.init_weapon_in(0, 0, 0)
			new_quick.init_weapon_res(0, 0, 0)
			new_quick.init_item_in(0, 0, 0)
			new_quick.init_item_res(0, 0, 0)
			server_agents[new_agent]["small_hud"] = new_quick
			_quick_views.add_child(server_agents[new_agent]["small_hud"])
	else:
		client_agents[new_agent] = {}
		if multiplayer.multiplayer_peer.get_unique_id() == player_id:
			var new_quick : HUDAgentSmall = hud_agent_small_scene.instantiate()
			new_quick.update_state("active")
			new_quick.update_item("none")
			new_quick.update_weapon("none")
			new_quick.init_weapon_in(0, 0, 0)
			new_quick.init_weapon_res(0, 0, 0)
			new_quick.init_item_in(0, 0, 0)
			new_quick.init_item_res(0, 0, 0)
			client_agents[new_agent]["small_hud"] = new_quick
			_quick_views.add_child(server_agents[new_agent]["small_hud"])

	pass

func _hud_agent_details_actions(agent : Agent): #TODO
	($World/Camera3D as Camera3D).unproject_position(agent.position)
	pass
