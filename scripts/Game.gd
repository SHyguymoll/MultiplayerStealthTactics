class_name Game
extends Node3D

var agent_scene = preload("res://scenes/agent.tscn")
var hud_agent_small_scene = preload("res://scenes/hud_agent_small.tscn")
var movement_icon_scene = preload("res://scenes/game_movement_indicator.tscn")

var server_agents : Dictionary
var client_agents : Dictionary

var server_ready_bool := false
var client_ready_bool := false

var action_timeline := {

}
var current_game_step := 0

enum GamePhases {
	SELECTION,
	EXECUTION,
}
var game_phase : GamePhases = GamePhases.SELECTION
enum SelectionSteps {
	BASE,
	MOVEMENT,
	AIMING,
}
var selection_step : SelectionSteps = SelectionSteps.BASE
@export var game_map : GameMap

@onready var _quick_views : HBoxContainer = $HUDBase/QuickViews
@onready var _radial_menu = $HUDSelected/RadialMenu
@onready var _execute_button : Button = $HUDBase/Execute
@onready var _phase_label : Label = $HUDBase/CurrentPhase

func _ready():
	# Preconfigure game.
	server_agents = {}
	client_agents = {}
	_radial_menu.visible = false
	multiplayer.multiplayer_peer = Lobby.multiplayer.multiplayer_peer
	Lobby.player_loaded.rpc_id(1) # Tell the server that this peer has loaded.
	_update_game_phase(GamePhases.SELECTION)


# Called only on the server.
func start_game():
	# All peers are ready to receive RPCs in this scene.
	await get_tree().create_timer(0.25).timeout #...after waiting for them to completely load in
	ping.rpc()
	server_populate_variables()
	#send_populated_dictionaries.rpc_id(other_player)
	force_camera.rpc_id(GameSettings.server_client_id, (game_map.agent_spawn_client_1.position + game_map.agent_spawn_client_2.position + game_map.agent_spawn_client_3.position + game_map.agent_spawn_client_4.position)/4, 20)
	force_camera((game_map.agent_spawn_server_1.position + game_map.agent_spawn_server_2.position + game_map.agent_spawn_server_3.position + game_map.agent_spawn_server_4.position)/4, 20)
	pass


@rpc("authority", "call_remote", "reliable")
func force_camera(new_pos, new_fov = -1.0):
	if new_pos is Vector2:
		$World/Camera3D.final_position = new_pos * Vector2(get_viewport().size/$World/Camera3D.sensitivity)
	elif new_pos is Vector3:
		$World/Camera3D.final_position = Vector2(new_pos.x, new_pos.z) * Vector2(get_viewport().size/$World/Camera3D.sensitivity)
	if new_fov != -1.0:
		$World/Camera3D.fov_target = new_fov


func create_sound_effect() -> void: #TODO
	pass


func create_popup() -> void: #TODO
	pass


func update_text() -> void:
	$HUDBase/AgentInstructions.text = ""
	if multiplayer.multiplayer_peer.get_unique_id() == 1:
		for agent in server_agents:
			$HUDBase/AgentInstructions.text += server_agents[agent]["text"]
			$HUDBase/AgentInstructions.text += "\n"

	else:
		for agent in client_agents:
			$HUDBase/AgentInstructions.text += client_agents[agent]["text"]
			$HUDBase/AgentInstructions.text += "\n"


func _physics_process(delta: float) -> void:
	match game_phase:
		GamePhases.SELECTION:
			if server_ready_bool and client_ready_bool:
				_update_game_phase(GamePhases.EXECUTION)
		GamePhases.EXECUTION:
			for agent in ($Agents.get_children() as Array[Agent]):
				agent._game_step(delta)
			for indicator in ($MovementOrders.get_children() + $AimingOrders.get_children()):
				indicator._game_step(delta)
			current_game_step += 1
			for age in server_agents:
				if server_agents[age]["action_done"] == false:
					return
			for age in client_agents:
				if client_agents[age]["action_done"] == false:
					return
			_update_game_phase(GamePhases.SELECTION)


func server_populate_variables(): #TODO
	# server's agents
	var spawn = game_map.agent_spawn_server_1
	create_agent.rpc(
			1,
			Lobby.players[1].agents[0],
			spawn.position.x, spawn.position.y, spawn.position.z, spawn.rotation.y)
	if len(Lobby.players[1].agents) > 1:
		spawn = game_map.agent_spawn_server_2
		create_agent.rpc(
				1,
				Lobby.players[1].agents[1],
				spawn.position.x, spawn.position.y, spawn.position.z, spawn.rotation.y)
	if len(Lobby.players[1].agents) > 2:
		spawn = game_map.agent_spawn_server_3
		create_agent.rpc(
				1,
				Lobby.players[1].agents[2],
				spawn.position.x, spawn.position.y, spawn.position.z, spawn.rotation.y)
	if len(Lobby.players[1].agents) > 3:
		spawn = game_map.agent_spawn_server_4
		create_agent.rpc(
				1,
				Lobby.players[1].agents[3],
				spawn.position.x, spawn.position.y, spawn.position.z, spawn.rotation.y)
	# client's agents
	spawn = game_map.agent_spawn_client_1
	create_agent.rpc(
			GameSettings.server_client_id,
			Lobby.players[GameSettings.server_client_id].agents[0],
			spawn.position.x, spawn.position.y, spawn.position.z, spawn.rotation.y)
	if len(Lobby.players[GameSettings.server_client_id].agents) > 1:
		spawn = game_map.agent_spawn_client_2
		create_agent.rpc(
				GameSettings.server_client_id,
				Lobby.players[GameSettings.server_client_id].agents[1],
				spawn.position.x, spawn.position.y, spawn.position.z, spawn.rotation.y)
	if len(Lobby.players[GameSettings.server_client_id].agents) > 2:
		spawn = game_map.agent_spawn_client_3
		create_agent.rpc(
				GameSettings.server_client_id,
				Lobby.players[GameSettings.server_client_id].agents[2],
				spawn.position.x, spawn.position.y, spawn.position.z, spawn.rotation.y)
	if len(Lobby.players[GameSettings.server_client_id].agents) > 3:
		spawn = game_map.agent_spawn_client_4
		create_agent.rpc(
				GameSettings.server_client_id,
				Lobby.players[GameSettings.server_client_id].agents[3],
				spawn.position.x, spawn.position.y, spawn.position.z, spawn.rotation.y)


@rpc("authority", "call_local", "reliable")
func append_action_timeline(agent, actions):
	if not action_timeline.has(current_game_step):
		action_timeline[current_game_step] = {}
	action_timeline[current_game_step][agent] = actions
	print(action_timeline)


@rpc("call_local")
func ping():
	print("{0}: pong!".format([multiplayer.multiplayer_peer.get_unique_id()]))

#func _add_player(id = 1):
	#var new_player = player_scene.instantiate()
	#new_player.name = str(id)
	#call_deferred("add_child", new_player)

@rpc("authority", "call_local", "reliable")
func create_agent(player_id, agent_stats, pos_x, pos_y, pos_z, rot_y): #TODO
	#print("{0}: attempting to spawn agent".format([player_id]))
	#print(agent_stats)
	var new_agent = agent_scene.instantiate()
	new_agent.name = str(player_id) + "_" + str(agent_stats.name)
	new_agent.agent_selected.connect(_hud_agent_details_actions)
	new_agent.action_completed.connect(_agent_completed_action)
	new_agent.action_interrupted.connect(_agent_interrupted)

	new_agent.spotted_agent.connect(_agent_sees_agent)
	new_agent.unspotted_agent.connect(_agent_lost_agent)
	new_agent.spotted_element
	new_agent.unspotted_element
	new_agent.heard_sound
	new_agent.agent_died.connect(_agent_died)

	new_agent.position = Vector3(pos_x, pos_y, pos_z)
	new_agent.rotation.y = rot_y
	new_agent.set_multiplayer_authority(player_id)
	$Agents.add_child(new_agent)

	if player_id == 1:
		server_agents[new_agent.name] = {agent_node=new_agent, action_array=[], action_done=true}
		if multiplayer.multiplayer_peer.get_unique_id() == player_id:
			server_agents[new_agent.name]["small_hud"] = hud_agent_small_scene.instantiate()
			_quick_views.add_child(server_agents[new_agent.name]["small_hud"])
			server_agents[new_agent.name]["small_hud"].update_state("active")
			server_agents[new_agent.name]["small_hud"].update_item("none")
			server_agents[new_agent.name]["small_hud"].update_weapon("none")
			server_agents[new_agent.name]["small_hud"].init_weapon_in(0, 0, 0)
			server_agents[new_agent.name]["small_hud"].init_weapon_res(0, 0, 0)

			server_agents[new_agent.name]["text"] = ""


	else:
		client_agents[new_agent.name] = {agent_node=new_agent, action_array=[], action_done=true}
		if multiplayer.multiplayer_peer.get_unique_id() == player_id:
			client_agents[new_agent.name]["small_hud"] = hud_agent_small_scene.instantiate()
			_quick_views.add_child(client_agents[new_agent.name]["small_hud"])
			client_agents[new_agent.name]["small_hud"].update_state("active")
			client_agents[new_agent.name]["small_hud"].update_item("none")
			client_agents[new_agent.name]["small_hud"].update_weapon("none")
			client_agents[new_agent.name]["small_hud"].init_weapon_in(0, 0, 0)
			client_agents[new_agent.name]["small_hud"].init_weapon_res(0, 0, 0)

			client_agents[new_agent.name]["text"] = ""
			client_agents[new_agent.name]["action_done"] = true
	print("{0}\n--------------\nSERVER = {1}\nCLIENT = {2}".format([multiplayer.multiplayer_peer.get_unique_id(), server_agents, client_agents]))


func _agent_sees_agent(spotter : Agent, spottee : Agent):
	if not spotter.is_multiplayer_authority():
		return
	var dist = spotter.position.distance_to(spottee.position)
	var sight_chance = dist * (spotter.eye_strength**dist) / (spottee.camo_level)
	if spotter.get_multiplayer_authority() == spottee.get_multiplayer_authority():
		pass


func _agent_lost_agent(unspotter : Agent, unspottee : Agent):
	if not unspotter.is_multiplayer_authority():
		return
	if unspotter.get_multiplayer_authority() != unspottee.get_multiplayer_authority():
		pass


func _agent_heard_something(listener : Agent, sound : Node3D):
	pass


func _agent_died(deceased : Agent):
	print(deceased.name, " has died, big f")
	if deceased.get_multiplayer_authority() == 1:
		if deceased.percieved_by_friendly:
			(server_agents[deceased]["small_hud"] as HUDAgentSmall).update_state(GameIcons.STE.dead)
		else:
			(server_agents[deceased]["small_hud"] as HUDAgentSmall).update_state(GameIcons.STE.unknown)
	else:
		if deceased.percieved_by_friendly:
			(client_agents[deceased]["small_hud"] as HUDAgentSmall).update_state(GameIcons.STE.dead)
		else:
			(client_agents[deceased]["small_hud"] as HUDAgentSmall).update_state(GameIcons.STE.unknown)
	pass


func _hud_agent_details_actions(agent : Agent): #TODO
	if game_phase != GamePhases.SELECTION:
		return
	if selection_step != SelectionSteps.BASE:
		return
	if not agent.is_multiplayer_authority():
		return
	if agent.in_incapacitated_state() and not agent.percieved_by_friendly:
		return
	agent.flash_outline(Color.AQUA)
	_radial_menu.referenced_agent = agent
	_radial_menu.position = (
			$World/Camera3D as Camera3D).unproject_position(
					agent.position).clamp(Vector2(get_window().size) - get_window().size * 0.85, get_window().size * 0.85)
	_radial_menu.init_menu()
	pass


func _agent_completed_action(agent : Agent): #TODO
	if agent.get_multiplayer_authority() == 1:
		server_agents[agent.name]["action_done"] = true
	else:
		client_agents[agent.name]["action_done"] = true
	if not agent.is_multiplayer_authority():
		return
	if len(agent.queued_action) == 0:
		return
	agent.flash_outline(Color.GREEN)


func _agent_interrupted(agent : Agent): #TODO
	if agent.get_multiplayer_authority() == 1:
		server_agents[agent.name]["action_done"] = true
	else:
		client_agents[agent.name]["action_done"] = true
	if not agent.is_multiplayer_authority():
		return
	if len(agent.queued_action) == 0:
		return
	agent.flash_outline(Color.RED)


func _on_radial_menu_decision_made(decision_array: Array) -> void:
	var ref_ag : Agent = _radial_menu.referenced_agent
	_radial_menu.referenced_agent = null
	# need to remove movement indicator if created
	for indicator in $MovementOrders.get_children():
		if indicator.referenced_agent == ref_ag:
			indicator.queue_free()
	# ditto with aiming indicator
	for indicator in $AimingOrders.get_children():
		if indicator.referenced_agent == ref_ag:
			indicator.queue_free()
	var final_text_string := ""
	match decision_array[0]:
		Agent.GameActions.GO_STAND:
			final_text_string = "{0}: Stand Up".format([ref_ag.name])
		Agent.GameActions.GO_CROUCH:
			final_text_string = "{0}: Crouch".format([ref_ag.name])
		Agent.GameActions.GO_PRONE:
			final_text_string = "{0}: Go Prone".format([ref_ag.name])
		Agent.GameActions.LOOK_AROUND:
			final_text_string = "{0}: Survey Area".format([ref_ag.name])
		Agent.GameActions.CHANGE_ITEM:
			final_text_string = "{0}: Equip ".format([ref_ag.name])
			match decision_array[1]:
				GameIcons.ITM.none:
					final_text_string = "{0}: Unequip Item".format([ref_ag.name])
				GameIcons.ITM.box:
					final_text_string += "Cardboard Box"
				GameIcons.ITM.cigar:
					final_text_string += "Cigar"
				GameIcons.ITM.analyzer:
					final_text_string += "Kit Analyzer"
				GameIcons.ITM.body_armor:
					final_text_string += "Body Armor"
				GameIcons.ITM.reflex_enhancer:
					final_text_string += "Reflex Pill"
				GameIcons.ITM.fake_death:
					final_text_string += "False Death Pill"
		Agent.GameActions.CHANGE_WEAPON:
			final_text_string = "{0}: Switch to ".format([ref_ag.name])
			match decision_array[1]:
				GameIcons.WEP.fist:
					final_text_string += "Hand to Hand"
				GameIcons.WEP.pistol:
					final_text_string += "Sidearm"
				GameIcons.WEP.rifle:
					final_text_string += "Rifle"
				GameIcons.WEP.shotgun:
					final_text_string += "Shotugn"
				GameIcons.WEP.grenade_frag:
					final_text_string += "Fragmentation Grenade"
				GameIcons.WEP.grenade_smoke:
					final_text_string += "Smoke Grenade"
				GameIcons.WEP.noise_maker:
					final_text_string += "Audio Disturber"
				GameIcons.WEP.middle_flag:
					final_text_string += "Flag (player should not see this)"
				GameIcons.WEP.enemy_flag:
					final_text_string += "Flag (player should not see this)"
		Agent.GameActions.PICK_UP_ITEM:
			final_text_string = "{0}: Pick up ".format([ref_ag.name])
			match decision_array[1]:
				GameIcons.ITM.none:
					final_text_string = "{0}: Unequip Item".format([ref_ag.name])
				GameIcons.ITM.box:
					final_text_string += "Cardboard Box"
				GameIcons.ITM.cigar:
					final_text_string += "Cigar"
				GameIcons.ITM.analyzer:
					final_text_string += "Kit Analyzer"
				GameIcons.ITM.body_armor:
					final_text_string += "Body Armor"
				GameIcons.ITM.reflex_enhancer:
					final_text_string += "Reflex Pill"
				GameIcons.ITM.fake_death:
					final_text_string += "False Death Pill"
			if len(decision_array) == 2:
				final_text_string += " and drop "
				match GameIcons.ITM.find_key(decision_array[1]):
					GameIcons.ITM.box:
						final_text_string += "Cardboard Box"
					GameIcons.ITM.cigar:
						final_text_string += "Cigar"
					GameIcons.ITM.analyzer:
						final_text_string += "Kit Analyzer"
					GameIcons.ITM.body_armor:
						final_text_string += "Body Armor"
					GameIcons.ITM.reflex_enhancer:
						final_text_string += "Reflex Pill"
					GameIcons.ITM.fake_death:
						final_text_string += "False Death Pill"
		Agent.GameActions.PICK_UP_WEAPON:
			final_text_string = "{0}: Pick up ".format([ref_ag.name])
			match decision_array[1]:
				GameIcons.WEP.fist:
					final_text_string += "Hand to Hand (how would they even do this???)"
				GameIcons.WEP.pistol:
					final_text_string += "Sidearm"
				GameIcons.WEP.rifle:
					final_text_string += "Rifle"
				GameIcons.WEP.shotgun:
					final_text_string += "Shotugn"
				GameIcons.WEP.grenade_frag:
					final_text_string += "Fragmentation Grenade"
				GameIcons.WEP.grenade_smoke:
					final_text_string += "Smoke Grenade"
				GameIcons.WEP.noise_maker:
					final_text_string += "Audio Disturber"
				GameIcons.WEP.middle_flag:
					final_text_string += "Flag"
				GameIcons.WEP.enemy_flag:
					final_text_string += "Flag"
			if len(decision_array) == 2:
				final_text_string += " and drop "
				match GameIcons.WEP.find_key(decision_array[1]):
					GameIcons.WEP.pistol:
						final_text_string += "Sidearm"
					GameIcons.WEP.rifle:
						final_text_string += "Rifle"
					GameIcons.WEP.shotgun:
						final_text_string += "Shotugn"
					GameIcons.WEP.grenade_frag:
						final_text_string += "Fragmentation Grenade"
					GameIcons.WEP.grenade_smoke:
						final_text_string += "Smoke Grenade"
					GameIcons.WEP.noise_maker:
						final_text_string += "Audio Disturber"
					GameIcons.WEP.middle_flag:
						final_text_string += "Flag"
					GameIcons.WEP.enemy_flag:
						final_text_string += "Flag"
		Agent.GameActions.HALT:
			final_text_string = "{0}: Stop ".format([ref_ag.name])
			match ref_ag.state:
				Agent.States.RUN:
					final_text_string += "Running"
				Agent.States.WALK:
					final_text_string += "Walking"
				Agent.States.CROUCH_WALK:
					final_text_string += "Sneaking"
				Agent.States.CRAWL:
					final_text_string += "Crawling"

	if multiplayer.multiplayer_peer.get_unique_id() == 1:
		server_agents[ref_ag.name]["text"] = final_text_string
		server_agents[ref_ag.name]["action_array"] = decision_array
	else:
		client_agents[ref_ag.name]["text"] = final_text_string
		client_agents[ref_ag.name]["action_array"] = decision_array
	update_text()


func _on_radial_menu_movement_decision_made(decision_array: Array) -> void:
	var ref_ag : Agent = _radial_menu.referenced_agent
	_radial_menu.referenced_agent = null
	# need to remove previous movement indicator if created
	for indicator in $MovementOrders.get_children():
		if indicator.referenced_agent == ref_ag:
			indicator.queue_free()
	# ditto with aiming indicator
	for indicator in $AimingOrders.get_children():
		if indicator.referenced_agent == ref_ag:
			indicator.queue_free()
	ref_ag.queued_action = decision_array
	selection_step = SelectionSteps.MOVEMENT
	var new_indicator = movement_icon_scene.instantiate()
	new_indicator.referenced_agent = ref_ag
	$MovementOrders.add_child(new_indicator)
	await new_indicator.indicator_placed
	selection_step = SelectionSteps.BASE
	decision_array.append(new_indicator.position)
	var final_text_string := ""
	match decision_array[0]:
		Agent.GameActions.RUN_TO_POS:
			final_text_string = "{0}: Run ".format([ref_ag.name])
		Agent.GameActions.WALK_TO_POS:
			final_text_string = "{0}: Walk ".format([ref_ag.name])
		Agent.GameActions.CROUCH_WALK_TO_POS:
			final_text_string = "{0}: Sneak ".format([ref_ag.name])
		Agent.GameActions.CRAWL_TO_POS:
			final_text_string = "{0}: Crawl ".format([ref_ag.name])
	final_text_string += "to New Position"
	if multiplayer.multiplayer_peer.get_unique_id() == 1:
		server_agents[ref_ag.name]["text"] = final_text_string
		server_agents[ref_ag.name]["action_array"] = decision_array
	else:
		client_agents[ref_ag.name]["text"] = final_text_string
		client_agents[ref_ag.name]["action_array"] = decision_array
	update_text()


func _on_radial_menu_aiming_decision_made(decision_array: Array) -> void:
	var ref_ag : Agent = _radial_menu.referenced_agent
	_radial_menu.referenced_agent = null
	# need to remove movement indicator if created
	for indicator in $MovementOrders.get_children():
		if indicator.referenced_agent == ref_ag:
			indicator.queue_free()
	# ditto with aiming indicator
	for indicator in $AimingOrders.get_children():
		if indicator.referenced_agent == ref_ag:
			indicator.queue_free()
	selection_step = SelectionSteps.AIMING
	selection_step = SelectionSteps.BASE


@rpc("authority", "call_local", "reliable")
func _update_game_phase(new_phase: GamePhases):
	match new_phase:
		GamePhases.SELECTION:
			_phase_label.text = "SELECT ACTIONS"
			_execute_button.set_pressed_no_signal(false)
			_execute_button.disabled = false
			for ag in server_agents:
				server_agents[ag]["agent_node"].queued_action = []
				server_agents[ag]["action_array"] = []
			for ag in client_agents:
				client_agents[ag]["agent_node"].queued_action = []
				client_agents[ag]["action_array"] = []
		GamePhases.EXECUTION:
			_phase_label.text = "EXECUTING ACTIONS..."
			server_ready_bool = false
			client_ready_bool = false
			# populate agents with actions, as well as action_timeline
			for ag in server_agents:
				server_agents[ag]["agent_node"].queued_action = server_agents[ag]["action_array"]
				server_agents[ag]["action_done"] = false
				if multiplayer.is_server():
					append_action_timeline.rpc(ag, server_agents[ag]["action_array"])
			for ag in client_agents:
				client_agents[ag]["agent_node"].queued_action = client_agents[ag]["action_array"]
				client_agents[ag]["action_done"] = false
				if multiplayer.is_server():
					append_action_timeline.rpc(ag, client_agents[ag]["action_array"])
			for agent in ($Agents.get_children() as Array[Agent]):
				agent.perform_action()
	game_phase = new_phase


@rpc("authority", "call_remote", "reliable")
func recieve_server_insts(recieved_dict : Dictionary):
	print("SERVER:\n" + str(recieved_dict))
	for agent_rec in recieved_dict:
		server_agents[agent_rec]["action_array"] = recieved_dict[agent_rec]["action_array"]
		server_agents[agent_rec]["action_done"] = recieved_dict[agent_rec]["action_done"]
	server_ready_bool = true


@rpc("any_peer", "call_remote", "reliable")
func recieve_client_insts(recieved_dict : Dictionary):
	print("CLIENT:\n" + str(recieved_dict))
	for agent_rec in recieved_dict:
		client_agents[agent_rec]["action_array"] = recieved_dict[agent_rec]["action_array"]
		client_agents[agent_rec]["action_done"] = recieved_dict[agent_rec]["action_done"]
	client_ready_bool = true


func _on_execute_toggled(toggled_on: bool) -> void:
	_execute_button.disabled = true
	if multiplayer.is_server():
		recieve_server_insts.rpc_id(GameSettings.server_client_id, server_agents)
		server_ready_bool = true
	else:
		recieve_client_insts.rpc_id(1, client_agents)
		client_ready_bool = true
