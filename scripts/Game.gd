class_name Game
extends Node3D

var agent_scene = preload("res://scenes/agent.tscn")
var agent_selector_scene = preload("res://scenes/agent_selector.tscn")
var hud_agent_small_scene = preload("res://scenes/hud_agent_small.tscn")
var movement_icon_scene = preload("res://scenes/game_movement_indicator.tscn")
var aiming_icon_scene = preload("res://scenes/game_aiming_indicator.tscn")

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
@onready var _ag_insts : Label = $HUDBase/AgentInstructions

func _ready():
	# Preconfigure game.
	server_agents = {}
	client_agents = {}
	_radial_menu.visible = false
	multiplayer.multiplayer_peer = Lobby.multiplayer.multiplayer_peer
	Lobby.player_loaded.rpc_id(1) # Tell the server that this peer has loaded.



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
	_ag_insts.text = ""
	if multiplayer.multiplayer_peer.get_unique_id() == 1:
		for agent in server_agents:
			_ag_insts.text += server_agents[agent]["text"]
			_ag_insts.text += "\n"

	else:
		for agent in client_agents:
			_ag_insts.text += client_agents[agent]["text"]
			_ag_insts.text += "\n"


func _physics_process(delta: float) -> void:
	match game_phase:
		GamePhases.SELECTION:
			for selector in $HUDSelectors.get_children() as Array[AgentSelector]:
				selector.position = (
			$World/Camera3D as Camera3D).unproject_position(
					selector.referenced_agent.position)# - selector.get_size()/2
			if server_ready_bool and client_ready_bool:
				_update_game_phase(GamePhases.EXECUTION)
				if multiplayer.is_server():
					for age in server_agents:
						server_agents[age]["text"] = ""
				else:
					for age in client_agents:
						client_agents[age]["text"] = ""
				update_text()
		GamePhases.EXECUTION:
			for agent in ($Agents.get_children() as Array[Agent]):
				agent._game_step(delta)
			determine_cqc_events()
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


@rpc("call_local")
func ping():
	print("{0}: pong!".format([multiplayer.multiplayer_peer.get_unique_id()]))

@rpc("authority", "call_local", "reliable")
func create_agent(player_id, agent_stats, pos_x, pos_y, pos_z, rot_y): #TODO
	var new_agent : Agent = agent_scene.instantiate()
	new_agent.name = str(player_id) + "_" + str(agent_stats.name)
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
	new_agent.health = agent_stats.health
	new_agent.view_dist = agent_stats.view_dist
	new_agent.view_across = agent_stats.view_across
	new_agent.eye_strength = agent_stats.eye_strength
	new_agent.hearing_dist = agent_stats.hearing_dist
	new_agent.ear_strength = agent_stats.ear_strength
	new_agent.held_items = agent_stats.held_items
	new_agent.held_weapons.append(GameWeapon.new("fist", new_agent.name + "_fist"))
	for weapon in agent_stats.held_weapons:
		new_agent.held_weapons.append(GameWeapon.new(weapon, new_agent.name + "_" + weapon))
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
			server_agents[new_agent.name]["action_done"] = true

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


func create_agent_selector(agent : Agent):
	var new_selector = agent_selector_scene.instantiate()
	new_selector.referenced_agent = agent
	new_selector.agent_selected.connect(_hud_agent_details_actions)
	$HUDSelectors.add_child(new_selector)


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


func determine_cqc_events(): # assumes that the grabber is on a different team than the grabbee
	var cqc_actors = {}

	for grabber_name in server_agents.keys():
		var try : Agent = server_agents[grabber_name].agent_node
		if try.state != Agent.States.USING_WEAPON:
			continue # check correct state
		if GameRefs.WEP[try.held_weapons[try.selected_weapon].wep_name].name != GameRefs.WEP.fist.name:
			continue # check correct weapon
		if try.grabbed_agent == null:
			continue # check if we haven't already resolved this in the previous step
		cqc_actors[try] = try.grabbed_agent

	for grabber_name in client_agents.keys():
		var try : Agent = client_agents[grabber_name].agent_node
		if try.state != Agent.States.USING_WEAPON:
			continue
		if GameRefs.WEP[try.held_weapons[try.selected_weapon].wep_name].name != GameRefs.WEP.fist.name:
			continue
		if try.grabbed_agent == null:
			continue
		cqc_actors[try] = try.grabbed_agent

	for grabber in (cqc_actors.keys() as Array[Agent]):
		var grabbee : Agent = grabber.grabbed_agent
		print([grabber, grabbee, grabber.grabbed_agent, grabbee.grabbing_agent])
		grabber.grabbed_agent = null
		if grabbee in cqc_actors and grabber.get_multiplayer_authority() == 1: #client wins tiebreakers
			grabber._anim_state.travel("B_Stand_Attack_Whiff")
			continue
		grabber._anim_state.travel("B_Stand_Attack_Slam")
		grabbee.grabbing_agent = grabber
		print([grabber, grabbee, grabber.grabbed_agent, grabbee.grabbing_agent])
		grabbee.take_damage(3, true)
		grabbee.stun_time = 10 if grabbee.stun_health > 0 else 300
		grabbee._anim_state.travel("B_Hurt_Slammed")
		grabbee.state = Agent.States.GRABBED
		pass


func _agent_heard_something(listener : Agent, sound : Node3D):
	pass


func _agent_died(deceased : Agent):
	print(deceased.name, " has died, big f")
	if deceased.get_multiplayer_authority() == 1:
		if deceased.percieved_by_friendly:
			(server_agents[deceased]["small_hud"] as HUDAgentSmall).update_state(GameRefs.STE.dead)
		else:
			(server_agents[deceased]["small_hud"] as HUDAgentSmall).update_state(GameRefs.STE.unknown)
	else:
		if deceased.percieved_by_friendly:
			(client_agents[deceased]["small_hud"] as HUDAgentSmall).update_state(GameRefs.STE.dead)
		else:
			(client_agents[deceased]["small_hud"] as HUDAgentSmall).update_state(GameRefs.STE.unknown)
	for agent_selector in $HUDSelectors.get_children() as Array[AgentSelector]:
		if agent_selector.referenced_agent == deceased:
			agent_selector.queue_free()
			break
	pass


func _hud_agent_details_actions(agent_selector : AgentSelector): #TODO
	if game_phase != GamePhases.SELECTION:
		print(multiplayer.get_unique_id(), ": not in SELECTION MODE")
		return
	if selection_step != SelectionSteps.BASE:
		print(multiplayer.get_unique_id(), ": not on SelectionStep.BASE")
		return
	var agent = agent_selector.referenced_agent
	if agent.in_incapacitated_state() and not agent.percieved_by_friendly:
		print(multiplayer.get_unique_id(), ": agent is knocked out with no eyes on them")
		return
	agent.flash_outline(Color.AQUA)
	_radial_menu.referenced_agent = agent
	_radial_menu.position = agent_selector.position
	_radial_menu.init_menu()
	pass


func _agent_completed_action(agent : Agent): #TODO
	if agent.get_multiplayer_authority() == 1:
		server_agents[agent.name]["action_done"] = true
	else:
		client_agents[agent.name]["action_done"] = true
	if not agent.is_multiplayer_authority():
		return
	agent.flash_outline(Color.GREEN)


func _agent_interrupted(agent : Agent): #TODO
	if agent.get_multiplayer_authority() == 1:
		server_agents[agent.name]["action_done"] = true
	else:
		client_agents[agent.name]["action_done"] = true
	if not agent.is_multiplayer_authority():
		return
	agent.flash_outline(Color.RED)


func hide_hud():
	var twe = create_tween()
	twe.set_parallel(true)
	twe.set_trans(Tween.TRANS_CUBIC)
	twe.tween_property(_execute_button, "position:y", 970, 0.25).from(825)
	twe.tween_property(_quick_views, "position:y", 920, 0.25).from(712)
	twe.tween_property(_ag_insts, "position:x", 1638, 0.25).from(1059)


func show_hud():
	var twe = create_tween()
	twe.set_parallel(true)
	twe.set_trans(Tween.TRANS_SINE)
	twe.tween_property(_execute_button, "position:y", 825, 0.25).from(970)
	twe.tween_property(_quick_views, "position:y", 712, 0.25).from(920)
	twe.tween_property(_ag_insts, "position:x", 1059, 0.25).from(1638)


func _on_radial_menu_decision_made(decision_array: Array) -> void:
	var ref_ag : Agent = _radial_menu.referenced_agent
	_radial_menu.referenced_agent = null
	# need to remove movement indicator if created
	for indicator in $MovementOrders.get_children():
		if indicator.referenced_agent == ref_ag:
			indicator._neutral()
	# ditto with aiming indicator
	for indicator in $AimingOrders.get_children():
		if indicator.referenced_agent == ref_ag:
			indicator._neutral()
	ref_ag.queued_action = decision_array
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
			if decision_array[1] == GameRefs.ITM.none.name:
				final_text_string = "{0}: Unequip Item".format([ref_ag.name])
			else:
				final_text_string += GameRefs.ITM[decision_array[1]].name
		Agent.GameActions.CHANGE_WEAPON:
			final_text_string = "{0}: Switch to {1}".format([
				ref_ag.name,
				GameRefs.WEP[ref_ag.held_weapons[decision_array[1]].wep_name].name])
		Agent.GameActions.PICK_UP_WEAPON:
			final_text_string = "{0}: Pick up {1}".format([
				ref_ag.name,
				GameRefs.WEP[decision_array[1]].name])
			#if len(decision_array) == 3:
				#final_text_string += " and drop {0}".format([GameRefs.WEP[decision_array[2]].name])
		Agent.GameActions.DROP_WEAPON:
			final_text_string = "{0}: Drop {1}".format([
				ref_ag.name,
				GameRefs.WEP[ref_ag.held_weapons[decision_array[1]].wep_name].name])
		Agent.GameActions.RELOAD_WEAPON:
			final_text_string = "{0}: Reload {1}".format([
				ref_ag.name,
				GameRefs.WEP[ref_ag.held_weapons[ref_ag.selected_weapon].wep_name].name])
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
		null:
			ref_ag.queued_action = []
	if multiplayer.multiplayer_peer.get_unique_id() == 1:
		server_agents[ref_ag.name]["text"] = final_text_string
		client_recieve_single_action.rpc(ref_ag.name, decision_array, server_agents[ref_ag.name]["action_done"])
	else:
		client_agents[ref_ag.name]["text"] = final_text_string
		server_recieve_single_action.rpc(ref_ag.name, decision_array, client_agents[ref_ag.name]["action_done"])
	update_text()


func _on_radial_menu_movement_decision_made(decision_array: Array) -> void:
	var ref_ag : Agent = _radial_menu.referenced_agent
	_radial_menu.referenced_agent = null
	# need to remove previous movement indicator if created
	for indicator in $MovementOrders.get_children():
		if indicator.referenced_agent == ref_ag:
			indicator._neutral()
	# ditto with aiming indicator
	for indicator in $AimingOrders.get_children():
		if indicator.referenced_agent == ref_ag:
			indicator._neutral()
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
		client_recieve_single_action.rpc(ref_ag.name, decision_array, server_agents[ref_ag.name]["action_done"])
	else:
		client_agents[ref_ag.name]["text"] = final_text_string
		server_recieve_single_action.rpc(ref_ag.name, decision_array, client_agents[ref_ag.name]["action_done"])
	update_text()


func _on_radial_menu_aiming_decision_made(decision_array: Array) -> void:
	var ref_ag : Agent = _radial_menu.referenced_agent
	_radial_menu.referenced_agent = null
	# need to remove movement indicator if created
	for indicator in $MovementOrders.get_children():
		if indicator.referenced_agent == ref_ag:
			indicator._neutral()
	# ditto with aiming indicator
	for indicator in $AimingOrders.get_children():
		if indicator.referenced_agent == ref_ag:
			indicator._neutral()
	ref_ag.queued_action = decision_array
	selection_step = SelectionSteps.AIMING
	var new_indicator = aiming_icon_scene.instantiate()
	new_indicator.referenced_agent = ref_ag
	$MovementOrders.add_child(new_indicator)
	await new_indicator.indicator_placed
	selection_step = SelectionSteps.BASE
	decision_array.append(new_indicator.position)
	var final_text_string := ""
	match decision_array[0]:
		Agent.GameActions.LOOK_AROUND:
			final_text_string = "{0}: Look at Position".format([ref_ag.name])
		Agent.GameActions.USE_WEAPON:
			final_text_string = "{0}: Use {1} at Position".format(
				[ref_ag.name,
				GameRefs.WEP[ref_ag.held_weapons[ref_ag.selected_weapon].wep_name].name])

	if multiplayer.multiplayer_peer.get_unique_id() == 1:
		server_agents[ref_ag.name]["text"] = final_text_string
		client_recieve_single_action.rpc(ref_ag.name, decision_array, server_agents[ref_ag.name]["action_done"])
	else:
		client_agents[ref_ag.name]["text"] = final_text_string
		server_recieve_single_action.rpc(ref_ag.name, decision_array, client_agents[ref_ag.name]["action_done"])
	update_text()


@rpc("authority", "call_local", "reliable")
func _update_game_phase(new_phase: GamePhases, check_incap := true):
	game_phase = new_phase
	match new_phase:
		GamePhases.SELECTION:
			_phase_label.text = "SELECT ACTIONS"
			_execute_button.disabled = false
			_execute_button.text = "EXECUTE INSTRUCTIONS"
			if multiplayer.is_server():
				for ag in server_agents:
					var checked_agent = server_agents[ag]["agent_node"]
					if not checked_agent.in_incapacitated_state():
						create_agent_selector(checked_agent)
			else:
				for ag in client_agents:
					var checked_agent = client_agents[ag]["agent_node"]
					if not checked_agent.in_incapacitated_state():
						create_agent_selector(checked_agent)
			show_hud()
			if $HUDSelectors.get_child_count() == 0 and check_incap:
				_on_execute_pressed() # run the execute function since the player can't do anything
		GamePhases.EXECUTION:
			for selector in $HUDSelectors.get_children(): # remove previous selectors
				selector.queue_free()
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
			await get_tree().create_timer(0.10).timeout
			for agent in ($Agents.get_children() as Array[Agent]):
				agent.perform_action()


@rpc("any_peer", "call_local", "reliable")
func client_recieve_single_action(agent_name, action, done):
	server_agents[agent_name]["action_array"] = action
	server_agents[agent_name]["action_done"] = done


@rpc("any_peer", "call_local", "reliable")
func server_recieve_single_action(agent_name, action, done):
	client_agents[agent_name]["action_array"] = action
	client_agents[agent_name]["action_done"] = done


@rpc("any_peer", "call_local", "reliable")
func player_is_ready(id):
	if id == 1:
		server_ready_bool = true
	else:
		client_ready_bool = true

func _on_execute_pressed() -> void:
	_execute_button.disabled = true
	_execute_button.text = "WAITING FOR OPPONENT"
	_radial_menu.button_collapse_animation()
	hide_hud()
	player_is_ready.rpc(multiplayer.get_unique_id())


func _on_cold_boot_timer_timeout() -> void:
	_update_game_phase(GamePhases.SELECTION, false)
