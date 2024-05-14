class_name Game
extends Node3D

var hud_agent_small_scene = preload("res://scenes/hud_agent_small.tscn")

var server_agents : Dictionary
var client_agents : Dictionary

var selected_agent : Agent = null
@export var game_map : GameMap

@onready var _quick_views : HBoxContainer = $HUDBase/QuickViews
@onready var _radial_menu = $HUDSelected/RadialMenu

func _ready():
	debug_game()
	return
	# Preconfigure game.
	server_agents = {}
	client_agents = {}
	multiplayer.multiplayer_peer = Lobby.multiplayer.multiplayer_peer
	#Lobby.player_loaded.rpc_id(1) # Tell the server that this peer has loaded.

func debug_game():
	Lobby.players = {
		1:
			{name="test",
		agents=[
			{
				name="agent 1",
				mission_count=0,
				hp=10,
				view_dist=1.0,
				view_arc=1.0,
				items=[],
				weapons=[],
			},
		]},
		2:
			{name="test",
		agents=[
			{
				name="agent 1",
				mission_count=0,
				hp=10,
				view_dist=1.0,
				view_arc=1.0,
				items=[],
				weapons=[],
			},
		]}
	}
	GameSettings.server_client_id = 2
	GameSettings.selected_agents = [0]
	GameSettings.selected_agents = [0]
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(7000, 2)
	multiplayer.multiplayer_peer = peer
	start_game()

# Called only on the server.
func start_game():
	# All peers are ready to receive RPCs in this scene.
	ping.rpc()
	server_populate_agent_dictionaries()
	#send_populated_dictionaries.rpc_id(other_player)
	pass

func create_sound_effect() -> void: #TODO
	pass

func server_populate_agent_dictionaries(): #TODO
	# server's agents
	create_agent.rpc(
			1,
			Lobby.players[1].agents[0],
			game_map.agent_spawn_server_1)
	if len(Lobby.players[1].agents) > 1:
		create_agent.rpc(
				1,
				Lobby.players[1].agents[1],
				game_map.agent_spawn_server_2)
	if len(Lobby.players[1].agents) > 2:
		create_agent.rpc(
				1,
				Lobby.players[1].agents[2],
				game_map.agent_spawn_server_3)
	if len(Lobby.players[1].agents) > 3:
		create_agent.rpc(
				1,
				Lobby.players[1].agents[3],
				game_map.agent_spawn_server_4)
	# client's agents
	create_agent.rpc(
			GameSettings.server_client_id,
			Lobby.players[GameSettings.server_client_id].agents[0],
			game_map.agent_spawn_client_1)
	if len(Lobby.players[GameSettings.server_client_id].agents) > 1:
		create_agent.rpc(
				GameSettings.server_client_id,
				Lobby.players[GameSettings.server_client_id].agents[1],
				game_map.agent_spawn_client_2)
	if len(Lobby.players[GameSettings.server_client_id].agents) > 2:
		create_agent.rpc(
				GameSettings.server_client_id,
				Lobby.players[GameSettings.server_client_id].agents[2],
				game_map.agent_spawn_client_3)
	if len(Lobby.players[GameSettings.server_client_id].agents) > 3:
		create_agent.rpc(
				GameSettings.server_client_id,
				Lobby.players[GameSettings.server_client_id].agents[3],
				game_map.agent_spawn_client_4)
	pass

@rpc("call_local")
func ping():
	print("pong!")

#func _add_player(id = 1):
	#var new_player = player_scene.instantiate()
	#new_player.name = str(id)
	#call_deferred("add_child", new_player)

@rpc("authority", "call_local", "reliable")
func create_agent(player_id, agent_stats, spawn : Node3D): #TODO
	var new_agent = Agent.new()
	new_agent.name = str(player_id) + "_" + str(agent_stats.name)
	new_agent.agent_selected.connect(_hud_agent_details_actions)
	new_agent.agent_deselected.connect(_radial_menu.button_collapse_animation)
	new_agent.action_chosen
	new_agent.action_completed
	new_agent.action_interrupted
	new_agent.agent_died
	new_agent.position = spawn.position
	new_agent.rotation.y = spawn.rotation.y

	if player_id == 1:
		server_agents[new_agent] = {}
		if multiplayer.multiplayer_peer.get_unique_id() == player_id:
			server_agents[new_agent]["small_hud"] = hud_agent_small_scene.instantiate()
			_quick_views.add_child(server_agents[new_agent]["small_hud"])
			server_agents[new_agent]["small_hud"].update_state("active")
			server_agents[new_agent]["small_hud"].update_item("none")
			server_agents[new_agent]["small_hud"].update_weapon("none")
			server_agents[new_agent]["small_hud"].init_weapon_in(0, 0, 0)
			server_agents[new_agent]["small_hud"].init_weapon_res(0, 0, 0)

	else:
		client_agents[new_agent] = {}
		if multiplayer.multiplayer_peer.get_unique_id() == player_id:
			client_agents[new_agent]["small_hud"] = hud_agent_small_scene.instantiate()
			_quick_views.add_child(client_agents[new_agent]["small_hud"])
			client_agents[new_agent]["small_hud"].update_state("active")
			client_agents[new_agent]["small_hud"].update_item("none")
			client_agents[new_agent]["small_hud"].update_weapon("none")
			client_agents[new_agent]["small_hud"].init_weapon_in(0, 0, 0)
			client_agents[new_agent]["small_hud"].init_weapon_res(0, 0, 0)

	pass

func _hud_agent_details_actions(agent : Agent): #TODO
	if selected_agent:
		selected_agent.agent_deselected.emit(selected_agent)
	selected_agent = agent
	_radial_menu.referenced_agent = agent
	_radial_menu.position = (
			$World/Camera3D as Camera3D).unproject_position(
					agent.position).clamp(Vector2(get_window().size) - get_window().size * 0.85, get_window().size * 0.85)
	_radial_menu.init_menu()
	pass
