extends Node

# Multiplayer spawners
@onready var ag_spawner : MultiplayerSpawner = $"../AgentSpawner"
@onready var pickup_spawner : MultiplayerSpawner = $"../PickupSpawner"
@onready var weapon_spawner : MultiplayerSpawner = $"../WeaponSpawner"
@onready var grenade_spawner : MultiplayerSpawner = $"../GrenadeSpawner"
@onready var smoke_spawner : MultiplayerSpawner = $"../SmokeSpawner"

# Game actor scenes
var agent_scene = preload("res://scenes/agent.tscn")
var weapon_scene = preload("res://scenes/weapon.tscn")
var weapon_pickup_scene = preload("res://scenes/weapon_pickup.tscn")
var grenade_scene = preload("res://scenes/grenade.tscn")
var smoke_scene = preload("res://scenes/smoke.tscn")
var audio_event_scene = preload("res://scenes/game_audio_event.tscn")

# Other things needed to initialize and handle a game
@onready var load_timer : Timer = $"../MultiplayerLoadTimer"
@export var action_timeline := {

}
var current_game_step := 0

enum GamePhases {
	SELECTION,
	EXECUTION,
	COMPLETION,
}
@export var game_phase : GamePhases = GamePhases.SELECTION
const REMEMBER_TILL = 150

enum ProgressParts {
	INTRO = -1,
	NO_ADVANTAGE = 0,
	ITEM_HELD = 1,
	OBJECTIVE_COMPLETE = 2,
	SURVIVORS_EXFILTRATED = 3,
}

@export var server_progress : ProgressParts = ProgressParts.INTRO
@export var client_progress : ProgressParts = ProgressParts.INTRO

@export var grenades_in_existence = []
@export var exfiltration_queue = []

@export var game_map : GameMap
var server_ready_bool := false
var client_ready_bool := false


var sent_final_message = false
var sent_reward = false

@onready var ui = $"../UI"
@onready var game = $".."

func _ready() -> void:
	multiplayer.multiplayer_peer = Lobby.multiplayer.multiplayer_peer
	if multiplayer.is_server():
		ui.serv_name.text = Lobby.player_info.name
		ui.clie_name.text = GameSettings.other_player_name
	else:
		ui.serv_name.text = GameSettings.other_player_name
		ui.clie_name.text = Lobby.player_info.name

	ag_spawner.spawn_function = create_agent
	pickup_spawner.spawn_function = create_pickup
	weapon_spawner.spawn_function = create_weapon
	grenade_spawner.spawn_function = create_grenade
	smoke_spawner.spawn_function = create_smoke

	Lobby.player_loaded.rpc_id(1) # Tell the server that this peer has loaded.
	Lobby.player_disconnected.connect(player_quits)
	if not multiplayer.is_server():
		client_is_loaded.rpc_id(1)

@rpc("any_peer", "call_local")
func client_is_loaded():
	load_timer.start()


func player_quits(_peer_id):
	if game_phase == GamePhases.COMPLETION or server_progress > ProgressParts.NO_ADVANTAGE or client_progress > ProgressParts.NO_ADVANTAGE:
		return
	create_toast_update(GameRefs.TXT.forfeit, GameRefs.TXT.forfeit, false)
	$FadeOut/ColorRect/AnimatedSprite2D.play("victory")
	ui.animate_fade(true)
	update_game_phase(GamePhases.COMPLETION)


func init_game(): #TODO
	# spawn server's agents
	var spawn_point : SpawnPoint = game_map.agent_spawn_server_1
	var spawn_pos : Vector3 = spawn_point.get_spawn_point()
	var data = {
		player_id = 1,
		agent_stats = Lobby.players[1].agents[GameSettings.selected_agents[0]],
		pos_x = spawn_pos.x,
		pos_y = spawn_pos.y,
		pos_z = spawn_pos.z,
		rot_y = spawn_point.rotation.y,
	}
	ag_spawner.spawn(data)
	if len(GameSettings.selected_agents) > 1:
		spawn_point = game_map.agent_spawn_server_2
		spawn_pos = spawn_point.get_spawn_point()
		data.agent_stats = Lobby.players[1].agents[GameSettings.selected_agents[1]]
		data.pos_x = spawn_pos.x
		data.pos_y = spawn_pos.y
		data.pos_z = spawn_pos.z
		data.rot_y = spawn_point.rotation.y
		ag_spawner.spawn(data)
	if len(GameSettings.selected_agents) > 2:
		spawn_point = game_map.agent_spawn_server_3
		spawn_pos = spawn_point.get_spawn_point()
		data.agent_stats = Lobby.players[1].agents[GameSettings.selected_agents[2]]
		data.pos_x = spawn_pos.x
		data.pos_y = spawn_pos.y
		data.pos_z = spawn_pos.z
		data.rot_y = spawn_point.rotation.y
		ag_spawner.spawn(data)
	if len(GameSettings.selected_agents) > 3:
		spawn_point = game_map.agent_spawn_server_4
		spawn_pos = spawn_point.get_spawn_point()
		data.agent_stats = Lobby.players[1].agents[GameSettings.selected_agents[3]]
		data.pos_x = spawn_pos.x
		data.pos_y = spawn_pos.y
		data.pos_z = spawn_pos.z
		data.rot_y = spawn_point.rotation.y
		ag_spawner.spawn(data)
	# spawn client's agents
	spawn_point = game_map.agent_spawn_client_1
	spawn_pos = spawn_point.get_spawn_point()
	data.player_id = GameSettings.other_player_id
	data.agent_stats = Lobby.players[data.player_id].agents[GameSettings.client_selected_agents[0]]
	data.pos_x = spawn_pos.x
	data.pos_y = spawn_pos.y
	data.pos_z = spawn_pos.z
	data.rot_y = spawn_point.rotation.y
	ag_spawner.spawn(data)
	if len(GameSettings.client_selected_agents) > 1:
		spawn_point = game_map.agent_spawn_client_2
		spawn_pos = spawn_point.get_spawn_point()
		data.agent_stats = Lobby.players[data.player_id].agents[GameSettings.client_selected_agents[1]]
		data.pos_x = spawn_pos.x
		data.pos_y = spawn_pos.y
		data.pos_z = spawn_pos.z
		data.rot_y = spawn_point.rotation.y
		ag_spawner.spawn(data)
	if len(GameSettings.client_selected_agents) > 2:
		spawn_point = game_map.agent_spawn_client_3
		spawn_pos = spawn_point.get_spawn_point()
		data.agent_stats = Lobby.players[data.player_id].agents[GameSettings.client_selected_agents[2]]
		data.pos_x = spawn_pos.x
		data.pos_y = spawn_pos.y
		data.pos_z = spawn_pos.z
		data.rot_y = spawn_point.rotation.y
		ag_spawner.spawn(data)
	if len(GameSettings.client_selected_agents) > 3:
		spawn_point = game_map.agent_spawn_client_4
		spawn_pos = spawn_point.get_spawn_point()
		data.agent_stats = Lobby.players[data.player_id].agents[GameSettings.client_selected_agents[3]]
		data.pos_x = spawn_pos.x
		data.pos_y = spawn_pos.y
		data.pos_z = spawn_pos.z
		data.rot_y = spawn_point.rotation.y
		ag_spawner.spawn(data)
	# point camera in right spot
	game.force_camera.rpc_id(
		GameSettings.other_player_id,
		(game_map.agent_spawn_client_1.position + game_map.agent_spawn_client_2.position +
		game_map.agent_spawn_client_3.position + game_map.agent_spawn_client_4.position)/4, 20)
	game.force_camera(
		(game_map.agent_spawn_server_1.position + game_map.agent_spawn_server_2.position +
		game_map.agent_spawn_server_3.position + game_map.agent_spawn_server_4.position)/4, 20)


func _on_cold_boot_timer_timeout() -> void:
	if not multiplayer.is_server():
		return
	var data : Dictionary
	data.pickup = {}
	data.pickup.generate_weapon = true
	data.weapon = {}
	match game_map.objective:
		game_map.Objectives.CAPTURE_ENEMY_FLAG:
			# create server's flag
			data.pickup.pos_x = game_map.objective_params[0]
			data.pickup.pos_y = game_map.objective_params[1]
			data.pickup.pos_z = game_map.objective_params[2]
			data.pickup.server_knows = true
			data.pickup.client_knows = false
			data.pickup.wep_name = "map_flag_server"
			pickup_spawner.spawn(data.pickup)
			# create client's flag
			data.pickup.pos_x = game_map.objective_params[3]
			data.pickup.pos_y = game_map.objective_params[4]
			data.pickup.pos_z = game_map.objective_params[5]
			data.pickup.server_knows = false
			data.pickup.client_knows = true
			data.pickup.wep_name = "map_flag_client"
			pickup_spawner.spawn(data.pickup)
		game_map.Objectives.CAPTURE_CENTRAL_FLAG:
			# create central flag
			data.pickup.pos_x = game_map.objective_params[0]
			data.pickup.pos_y = game_map.objective_params[1]
			data.pickup.pos_z = game_map.objective_params[2]
			data.pickup.server_knows = true
			data.pickup.client_knows = true
			data.pickup.wep_name = "map_flag_center"
			pickup_spawner.spawn(data.pickup)
		game_map.Objectives.TARGET_DEFEND:
			game_map.objective_params
	update_game_phase.rpc(GamePhases.SELECTION, false)
	animate_fade.rpc(false)


@rpc("any_peer", "call_local", "reliable")
func player_is_ready(id):
	if id == 1:
		server_ready_bool = true
		if not multiplayer.is_server():
			ui.hurry_up.visible = true
	else:
		client_ready_bool = true
		if multiplayer.is_server():
			ui.hurry_up.visible = true
	if multiplayer.is_server() and server_ready_bool and client_ready_bool:
		update_game_phase.rpc(GamePhases.EXECUTION)


func _on_execute_pressed() -> void:
	player_is_ready.rpc(multiplayer.get_unique_id())


@rpc("authority", "call_local")
func animate_fade(in_out := true):
	ui.animate_fade(in_out)


func create_agent(data) -> Agent: #TODO
	var new_agent : Agent = agent_scene.instantiate()
	new_agent.name = str(data.player_id) + "_" + str(data.agent_stats.name)

	new_agent.position = Vector3(data.pos_x, data.pos_y, data.pos_z)
	new_agent.rotation.y = data.rot_y
	new_agent.set_multiplayer_authority(data.player_id)
	new_agent.player_id = data.player_id
	new_agent.health = data.agent_stats.health
	new_agent.stun_health = data.agent_stats.stun_health
	new_agent.view_dist = data.agent_stats.view_dist
	new_agent.view_across = data.agent_stats.view_across
	new_agent.eye_strength = data.agent_stats.eye_strength
	new_agent.hearing_dist = data.agent_stats.hearing_dist
	new_agent.held_items = data.agent_stats.held_items
	var weapon_data = {
		wep_id = "fist",
		wep_name = new_agent.name + "_fist",
		loaded_ammo = GameRefs.WEP["fist"].ammo,
		reserve_ammo = GameRefs.WEP["fist"].ammo * 3,
	}
	if multiplayer.is_server():
		weapon_spawner.spawn(weapon_data)
	new_agent.held_weapons.append(weapon_data.wep_name)
	for weapon in data.agent_stats.held_weapons:
		weapon_data.wep_id = weapon
		weapon_data.wep_name = new_agent.name + "_" + weapon
		weapon_data.loaded_ammo = GameRefs.WEP[weapon_data.wep_id].ammo
		weapon_data.reserve_ammo = GameRefs.WEP[weapon_data.wep_id].ammo * 3
		if multiplayer.is_server():
			weapon_spawner.spawn(weapon_data)
		new_agent.held_weapons.append(weapon_data.wep_name)
	new_agent.visible = false
	if multiplayer.get_unique_id() == data.player_id:
		if multiplayer.get_unique_id() == 1:
			new_agent.server_knows = true
		else:
			new_agent.client_knows = true
		ui.create_small_hud(data, new_agent)
	return new_agent


func create_weapon(data) -> GameWeapon:
	var new_weapon : GameWeapon = weapon_scene.instantiate()
	new_weapon.name = data.wep_name
	new_weapon.wep_id = data.wep_id
	new_weapon.loaded_ammo = data.loaded_ammo
	new_weapon.reserve_ammo = data.reserve_ammo
	return new_weapon


func create_grenade(data) -> Grenade:
	var new_grenade : Grenade = grenade_scene.instantiate()
	new_grenade.position = Vector3(data.pos_x, data.pos_y, data.pos_z)
	new_grenade.name = data.wep_name
	new_grenade.wep_id = data.wep_id
	new_grenade.player_id = data.player_id
	new_grenade.server_knows = data.server_knows
	new_grenade.client_knows = data.client_knows
	new_grenade.landing_position = Vector3(data.end_pos_x, data.end_pos_y, data.end_pos_z)
	return new_grenade


func create_smoke(data) -> Smoke:
	var new_smoke : Smoke = smoke_scene.instantiate()
	new_smoke.position = Vector3(data.pos_x, data.pos_y, data.pos_z)
	new_smoke.name = data.wep_name
	return new_smoke


func create_pickup(data) -> WeaponPickup:
	var new_pickup : WeaponPickup = weapon_pickup_scene.instantiate()
	new_pickup.position = Vector3(data.pos_x, data.pos_y, data.pos_z)
	new_pickup.server_knows = data.server_knows
	new_pickup.client_knows = data.client_knows
	new_pickup.name = data.wep_name
	new_pickup.attached_wep = data.wep_name
	new_pickup.generate_weapon = data.get("generate_weapon", false)
	return new_pickup


@rpc("authority", "call_local", "reliable")
func create_sound_effect(location : Vector3, player_id : int, lifetime : int, _min_rad : float, max_rad : float, sound_id : String) -> void:
	ui.create_sound_effect()
	var new_audio_event : GameAudioEvent = audio_event_scene.instantiate()
	new_audio_event.position = location
	new_audio_event.player_id = player_id
	new_audio_event.max_radius = max_rad
	new_audio_event.lifetime = lifetime
	new_audio_event.max_lifetime = lifetime
	new_audio_event.selected_audio = sound_id
	$AudioEvents.add_child(new_audio_event)


@rpc("authority", "call_local")
func create_toast_update(server_text : String, client_text : String, add_sound_effect : bool, color := Color(0.565, 0, 0.565, 0.212)):
	ui.create_toast(server_text if multiplayer.is_server() else client_text, add_sound_effect, color)


func track_objective_completion():
	match game_map.objective:
		GameMap.Objectives.CAPTURE_CENTRAL_FLAG:
			of_comp()


func of_comp():
	of_comp_server()
	of_comp_client()

func of_comp_server():
	match server_progress:
		ProgressParts.INTRO:
			create_toast_update.rpc(GameRefs.TXT.of_intro, GameRefs.TXT.of_intro, true)
			set_server_progress.rpc(ProgressParts.NO_ADVANTAGE)
		ProgressParts.NO_ADVANTAGE: # no one has the flag
			if not game.check_agents_for_weapon("map_flag_center"):
				return
			if not game.check_weapon_holder_exfil("map_flag_center"):
				create_toast_update.rpc(GameRefs.TXT.of_y_get, GameRefs.TXT.of_t_get, true)
				set_server_progress.rpc(ProgressParts.ITEM_HELD)
				return
			if not game.check_full_team_exfil_or_dead(true):
				create_toast_update.rpc(GameRefs.TXT.of_cap_agents_remain, GameRefs.TXT.of_cap_agents_remain, true)
				set_server_progress.rpc(ProgressParts.OBJECTIVE_COMPLETE)
				return
			create_toast_update.rpc(GameRefs.TXT.of_y_cap_left, GameRefs.TXT.of_t_cap_left, true)
			set_server_progress.rpc(ProgressParts.SURVIVORS_EXFILTRATED)
			return
		ProgressParts.ITEM_HELD: # the server team has the flag
			if not game.check_agents_for_weapon("map_flag_center"):
				create_toast_update.rpc(GameRefs.TXT.of_y_lost, GameRefs.TXT.of_t_lost, true)
				set_server_progress.rpc(ProgressParts.NO_ADVANTAGE)
				return
			if game.check_weapon_holder_exfil("map_flag_center"):
				if not game.check_full_team_exfil_or_dead(true):
					create_toast_update.rpc(GameRefs.TXT.of_cap_agents_remain, GameRefs.TXT.of_cap_agents_remain, true)
					set_server_progress.rpc(ProgressParts.OBJECTIVE_COMPLETE)
					return
				create_toast_update.rpc(GameRefs.TXT.of_y_cap_left, GameRefs.TXT.of_t_cap_left, true)
				set_server_progress.rpc(ProgressParts.SURVIVORS_EXFILTRATED)
				return
		ProgressParts.OBJECTIVE_COMPLETE: # a server team member has escaped with the flag
			if game.check_full_team_exfil_or_dead(true):
				create_toast_update.rpc(GameRefs.TXT.mission_success, GameRefs.TXT.mission_failure, true)
				set_server_progress.rpc(ProgressParts.SURVIVORS_EXFILTRATED)


func of_comp_client():
	match client_progress:
		ProgressParts.INTRO:
			set_client_progress.rpc(ProgressParts.NO_ADVANTAGE)
		ProgressParts.NO_ADVANTAGE: # no one has the flag
			if not game.check_agents_for_weapon("map_flag_center"):
				return
			if not game.check_weapon_holder_exfil("map_flag_center"):
				create_toast_update.rpc(GameRefs.TXT.of_t_get, GameRefs.TXT.of_y_get, true)
				set_client_progress.rpc(ProgressParts.ITEM_HELD)
				return
			if not game.check_full_team_exfil_or_dead():
				create_toast_update.rpc(GameRefs.TXT.of_cap_agents_remain, GameRefs.TXT.of_cap_agents_remain, true)
				set_client_progress.rpc(ProgressParts.OBJECTIVE_COMPLETE)
				return
			create_toast_update.rpc(GameRefs.TXT.of_t_cap_left, GameRefs.TXT.of_y_cap_left, true)
			set_client_progress.rpc(ProgressParts.SURVIVORS_EXFILTRATED)
			return
		ProgressParts.ITEM_HELD: # the client team has the flag
			if not game.check_agents_for_weapon("map_flag_center"):
				create_toast_update.rpc(GameRefs.TXT.of_t_lost, GameRefs.TXT.of_y_lost, true)
				set_client_progress.rpc(ProgressParts.NO_ADVANTAGE)
				return
			if game.check_weapon_holder_exfil("map_flag_center"):
				if not game.check_full_team_exfil_or_dead():
					ui.create_toast_update.rpc(GameRefs.TXT.of_cap_agents_remain, GameRefs.TXT.of_cap_agents_remain, true)
					set_client_progress.rpc(ProgressParts.OBJECTIVE_COMPLETE)
					return
				create_toast_update.rpc(GameRefs.TXT.of_t_cap_left, GameRefs.TXT.of_y_cap_left, true)
				set_client_progress.rpc(ProgressParts.SURVIVORS_EXFILTRATED)
				return
		ProgressParts.OBJECTIVE_COMPLETE: # a client team member has escaped with the flag
			if game.check_full_team_exfil_or_dead():
				create_toast_update.rpc(GameRefs.TXT.mission_failure, GameRefs.TXT.mission_success, true)
				set_client_progress.rpc(ProgressParts.SURVIVORS_EXFILTRATED)


func player_has_won(all_server_dead : bool, all_client_dead : bool) -> bool:
	if all_server_dead and all_client_dead and multiplayer.is_server() and not sent_reward:
		create_toast_update.rpc(GameRefs.TXT.any_a_dead, GameRefs.TXT.any_a_dead, false)
		failure_jingle()
		failure_jingle.rpc()
		sent_reward = true
	if not all_client_dead and (all_server_dead or client_progress == ProgressParts.SURVIVORS_EXFILTRATED):
		if multiplayer.is_server() and not sent_reward:
			if all_server_dead:
				create_toast_update.rpc(GameRefs.TXT.any_y_dead, GameRefs.TXT.any_t_dead, false)
			print("REWARDING CLIENT TEAM")
			reward_team.rpc_id(GameSettings.other_player_id)
			victory_jingle.rpc()
			failure_jingle()
			sent_reward = true
	if not all_server_dead and (all_client_dead or server_progress == ProgressParts.SURVIVORS_EXFILTRATED):
		if multiplayer.is_server() and not sent_reward:
			if all_client_dead:
				create_toast_update.rpc(GameRefs.TXT.any_t_dead, GameRefs.TXT.any_y_dead, false)
			print("REWARDING SERVER TEAM")
			reward_team()
			victory_jingle()
			failure_jingle.rpc()
			sent_reward = true
	return all_server_dead or all_client_dead or server_progress == ProgressParts.SURVIVORS_EXFILTRATED or client_progress == ProgressParts.SURVIVORS_EXFILTRATED


@rpc("authority", "call_remote", "reliable")
func victory_jingle():
	ui.music_progress.stop()
	ui.music_victory.play()
	ui.gameover_anim.play("victory")


@rpc("authority", "call_remote", "reliable")
func failure_jingle():
	ui.music_progress.stop()
	ui.music_failure.play()
	ui.gameover_anim.play("failure")


@rpc("authority", "reliable")
func reward_team():
	for ag in ($Agents.get_children() as Array[Agent]):
		if not ag.is_multiplayer_authority(): # pick the right team
			continue
		if ag.state == Agent.States.DEAD: # only the survivors
			continue
		var ag_name_local = ag.name.split("_", true, 1)[1]
		GameSettings.winning_agents.append(ag_name_local)


func append_action_timeline(agent : Agent):
	if not action_timeline.has(current_game_step):
		action_timeline[current_game_step] = {}
	action_timeline[current_game_step][agent.name] = agent.queued_action


@rpc("authority", "call_local", "reliable")
func set_server_progress(val : ProgressParts):
	server_progress = val


@rpc("authority", "call_local", "reliable")
func set_client_progress(val : ProgressParts):
	client_progress = val


@rpc("authority", "call_local", "reliable")
func update_game_phase(new_phase: GamePhases, check_incap := true):
	await get_tree().create_timer(0.1).timeout
	game_phase = new_phase
	match new_phase:
		GamePhases.SELECTION:
			ui.round_ended.play()
			ui.phase_label.text = "SELECT ACTIONS"
			ui.execute_button.disabled = false
			ui.execute_button.text = "EXECUTE INSTRUCTIONS"
			if multiplayer.is_server(): # update exfiltrations
				if server_progress == ProgressParts.ITEM_HELD:
					var can_exfil = false
					for detect in game_map.server_exfiltrate_zone.get_overlapping_areas():
						var actual_agent : Agent = detect.get_parent()
						if actual_agent.state == Agent.States.DEAD:
							continue
						for weap in actual_agent.held_weapons:
							if (weap as String).begins_with("map_"):
								can_exfil = true
								break
						if can_exfil:
							break
					if can_exfil:
						for detect in game_map.server_exfiltrate_zone.get_overlapping_areas():
							var actual_agent : Agent = detect.get_parent()
							if actual_agent.state == Agent.States.DEAD:
								continue
							exfiltration_queue.append(actual_agent.name)
				elif server_progress == ProgressParts.OBJECTIVE_COMPLETE:
					for detect in game_map.server_exfiltrate_zone.get_overlapping_areas():
						var actual_agent : Agent = detect.get_parent()
						if actual_agent.state == Agent.States.DEAD:
							continue
						exfiltration_queue.append(actual_agent.name)
				if client_progress == ProgressParts.ITEM_HELD:
					var can_exfil = false
					for detect in game_map.client_exfiltrate_zone.get_overlapping_areas():
						var actual_agent : Agent = detect.get_parent()
						if actual_agent.state == Agent.States.DEAD:
							continue
						for weap in actual_agent.held_weapons:
							if (weap as String).begins_with("map_"):
								can_exfil = true
								break
						if can_exfil:
							break
					if can_exfil:
						for detect in game_map.client_exfiltrate_zone.get_overlapping_areas():
							var actual_agent : Agent = detect.get_parent()
							if actual_agent.state == Agent.States.DEAD:
								continue
							exfiltration_queue.append(actual_agent.name)
				elif client_progress == ProgressParts.OBJECTIVE_COMPLETE:
					for detect in game_map.client_exfiltrate_zone.get_overlapping_areas():
						var actual_agent : Agent = detect.get_parent()
						if actual_agent.state == Agent.States.DEAD:
							continue
						exfiltration_queue.append(actual_agent.name)
			for agent_name in exfiltration_queue:
				($Agents.get_node(str(agent_name)) as Agent).exfiltrate()
			if multiplayer.is_server():
				track_objective_completion() # objective based updates here
			# create selectors and otherwise prepare for selection
			var server_team_dead = true
			var client_team_dead = true
			for ag in ($Agents.get_children() as Array[Agent]):
				ag.action_done = Agent.ActionDoneness.NOT_DONE
				ag.ungrabbable = false
				if multiplayer.is_server():
					set_agent_action.rpc(ag.name, [])
				if ag.is_multiplayer_authority() and not ag.in_incapacitated_state():
					ui.create_agent_selector(ag)
					ag.flash_outline(Color.ORCHID)
				if ag.state != Agent.States.DEAD:
					if ag.player_id == 1:
						server_team_dead = false
					else:
						client_team_dead = false
			if not game.player_has_won(server_team_dead, client_team_dead): # win conditions
				ui.show_hud()
				if $HUDSelectors.get_child_count() == 0 and check_incap:
					_on_execute_pressed() # run execute since the player can't do anything
			else:
				update_game_phase(GamePhases.COMPLETION)
		GamePhases.EXECUTION:
			$HUDBase/HurryUp.visible = false
			for agent in ($Agents.get_children() as Array[Agent]):
				agent.action_text = ""
			ui.update_text()
			ui.phase_label.text = "EXECUTING ACTIONS..."
			server_ready_bool = false
			client_ready_bool = false
			# populate agents with actions, as well as action_timeline
			for agent in ($Agents.get_children() as Array[Agent]):
				agent.agent_is_done.rpc(Agent.ActionDoneness.NOT_DONE)
				if multiplayer.is_server():
					append_action_timeline(agent)
				agent.perform_action()
			await get_tree().create_timer(0.10).timeout
		GamePhases.COMPLETION:
			game.save_replay()
			if multiplayer.is_server() and not sent_final_message:
				create_toast_update.rpc("GAME OVER", "GAME OVER", true, Color.INDIGO - Color(0, 0, 0, 1 - 0.212))
				animate_fade.rpc()
				sent_final_message = true
			$PauseMenu/ColorRect/CurrentPhase.text = "EXIT"
			ui.open_pause_menu()
			$PauseMenu/ColorRect/VBoxContainer/NoForfeit.visible = false
			$PauseMenu/ColorRect/VBoxContainer/NoForfeit.disabled = true


@rpc("any_peer", "call_local", "reliable")
func remove_weapon_from_agent(agent_name : String, weapon_name : String):
	$Agents.get_node(agent_name).held_weapons.erase(weapon_name)


@rpc("any_peer", "call_local", "reliable")
func set_agent_action(agent_name : String, action : Array):
	$Agents.get_node(agent_name).queued_action = action


@rpc("any_peer", "call_local", "reliable")
func set_agent_notice(agent_name : String, new_noticed : int):
	$Agents.get_node(agent_name).noticed = new_noticed

@rpc("any_peer", "call_local", "reliable")
func set_agent_step_seen(agent_name : String, new_step_seen : int):
	$Agents.get_node(agent_name).step_seen = new_step_seen


@rpc("any_peer", "call_local", "reliable")
func set_agent_server_visibility(agent_name : String, visibility : bool):
	$Agents.get_node(agent_name).server_knows = visibility


@rpc("any_peer", "call_local", "reliable")
func set_agent_client_visibility(agent_name : String, visibility : bool):
	$Agents.get_node(agent_name).client_knows = visibility


@rpc("authority", "call_local", "reliable")
func damage_agent(agent_name : String, damage_amt : int, stun : bool):
	($Agents.get_node(agent_name) as Agent).take_damage(damage_amt, stun)
