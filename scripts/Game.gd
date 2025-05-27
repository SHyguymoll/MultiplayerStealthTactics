class_name Game
extends Node3D

var agent_scene = preload("res://scenes/agent.tscn")
var agent_selector_scene = preload("res://scenes/agent_selector.tscn")
var weapon_scene = preload("res://scenes/weapon.tscn")
var hud_agent_small_scene = preload("res://scenes/hud_agent_small.tscn")
var toast_scene = preload("res://scenes/toast.tscn")
var movement_icon_scene = preload("res://scenes/game_movement_indicator.tscn")
var aiming_icon_scene = preload("res://scenes/game_aiming_indicator.tscn")
var tracking_raycast3d_scene = preload("res://scenes/tracking_raycast3d.tscn")
var popup_scene = preload("res://scenes/game_popup.tscn")
var audio_event_scene = preload("res://scenes/game_audio_event.tscn")
var weapon_pickup_scene = preload("res://scenes/weapon_pickup.tscn")
var grenade_scene = preload("res://scenes/grenade.tscn")
var smoke_scene = preload("res://scenes/smoke.tscn")

var server_ready_bool := false
var client_ready_bool := false

@export var action_timeline := {

}
var current_game_step := 0

enum GamePhases {
	SELECTION,
	EXECUTION,
	COMPLETION,
}
@export var game_phase : GamePhases = GamePhases.SELECTION

enum SelectionSteps {
	BASE,
	MOVEMENT,
	AIMING,
}
var selection_step : SelectionSteps = SelectionSteps.BASE

const REMEMBER_TILL = 150

@export var game_map : GameMap

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
@export var exfiltration_queue : Array[Agent] = []

@onready var _camera : GameCamera = $World/Camera3D
@onready var ag_spawner : MultiplayerSpawner = $AgentSpawner
@onready var pickup_spawner : MultiplayerSpawner = $PickupSpawner
@onready var weapon_spawner : MultiplayerSpawner = $WeaponSpawner
@onready var grenade_spawner : MultiplayerSpawner = $GrenadeSpawner
@onready var smoke_spawner : MultiplayerSpawner = $SmokeSpawner

@onready var _quick_views : HBoxContainer = $HUDBase/QuickViews
@onready var _radial_menu = $HUDSelected/RadialMenu
@onready var _execute_button : Button = $HUDBase/Execute
@onready var _phase_label : Label = $HUDBase/CurrentPhase
@onready var _ag_insts : Label = $HUDBase/AgentInstructions
@onready var _server_progress : ProgressBar = $HUDBase/ProgressBarServer
@onready var _client_progress : ProgressBar = $HUDBase/ProgressBarClient

@onready var _round_update : AudioStreamPlayer = $SoundEffects/RoundUpdate
@onready var _round_ended : AudioStreamPlayer = $SoundEffects/RoundEnded
@onready var _actions_submitted : AudioStreamPlayer = $SoundEffects/ActionsSubmitted

var start_time : String
var sent_reward = false

func _ready(): # Preconfigure game.
	_radial_menu.visible = false
	close_pause_menu()
	ag_spawner.spawn_function = create_agent
	pickup_spawner.spawn_function = create_pickup
	weapon_spawner.spawn_function = create_weapon
	grenade_spawner.spawn_function = create_grenade
	smoke_spawner.spawn_function = create_smoke

	$FadeOut.visible = true
	$FadeOut/ColorRect.modulate = Color.WHITE
	$HUDBase/HurryUp.visible = false
	multiplayer.multiplayer_peer = Lobby.multiplayer.multiplayer_peer
	if multiplayer.is_server():
		$HUDBase/ServerPlayerName.text = Lobby.player_info.name
		$HUDBase/ClientPlayerName.text = GameSettings.other_player_name
	else:
		$HUDBase/ServerPlayerName.text = GameSettings.other_player_name
		$HUDBase/ClientPlayerName.text = Lobby.player_info.name

	Lobby.player_loaded.rpc_id(1) # Tell the server that this peer has loaded.
	Lobby.player_disconnected.connect(player_quits)
	if not multiplayer.is_server():
		client_is_loaded.rpc_id(1)

@rpc("authority", "call_local")
func set_start_time(val):
	start_time = val


@rpc("any_peer")
func client_is_loaded():
	($MultiplayerLoadTimer as Timer).start()

func start_game(): # Called only on the server.
	await ($MultiplayerLoadTimer as Timer).timeout # wait for client to load in
	ping.rpc()
	set_start_time.rpc(str(int(Time.get_unix_time_from_system())))
	server_populate_variables()
	force_camera.rpc_id(
		GameSettings.other_player_id,
		(game_map.agent_spawn_client_1.position + game_map.agent_spawn_client_2.position +
		game_map.agent_spawn_client_3.position + game_map.agent_spawn_client_4.position)/4, 20)
	force_camera(
		(game_map.agent_spawn_server_1.position + game_map.agent_spawn_server_2.position +
		game_map.agent_spawn_server_3.position + game_map.agent_spawn_server_4.position)/4, 20)
	($ColdBootTimer as Timer).start()


func open_pause_menu():
	if not $PauseMenu.visible:
		$PauseMenu/ColorRect/VBoxContainer/YesForfeit.disabled = false
		$PauseMenu/ColorRect/VBoxContainer/NoForfeit.disabled = false
		$PauseMenu.visible = true


func close_pause_menu():
	$PauseMenu/ColorRect/VBoxContainer/YesForfeit.disabled = true
	$PauseMenu/ColorRect/VBoxContainer/NoForfeit.disabled = true
	$PauseMenu.visible = false

@rpc("authority", "call_remote", "reliable")
func force_camera(new_pos, new_fov = -1.0):
	if new_pos is Vector2:
		$World/Camera3D.final_position = new_pos * Vector2(get_viewport().size/$World/Camera3D.sensitivity)
	elif new_pos is Vector3:
		$World/Camera3D.final_position = Vector2(new_pos.x, new_pos.z) * Vector2(get_viewport().size/$World/Camera3D.sensitivity)
	if new_fov != -1.0:
		$World/Camera3D.fov_target = new_fov


@rpc("authority", "call_local", "reliable")
func create_sound_effect(location : Vector3, player_id : int, lifetime : int, _min_rad : float, max_rad : float, sound_id : String) -> void:
	var new_audio_event : GameAudioEvent = audio_event_scene.instantiate()
	new_audio_event.position = location
	new_audio_event.player_id = player_id
	new_audio_event.max_radius = max_rad
	new_audio_event.lifetime = lifetime
	new_audio_event.max_lifetime = lifetime
	new_audio_event.selected_audio = sound_id
	$AudioEvents.add_child(new_audio_event)

@rpc()
func create_popup(texture : Texture2D, location : Vector3, fleeting : bool = false) -> void:
	location.y = 3.0
	var new_popup : GamePopup = popup_scene.instantiate()
	new_popup.texture = texture
	new_popup.position = location
	$Popups.add_child(new_popup)
	if fleeting:
		new_popup.disappear()


func update_text() -> void:
	_ag_insts.text = ""
	for agent in ($Agents.get_children() as Array[Agent]):
		if agent.owned():
			_ag_insts.text += agent.action_text + "\n"

func determine_sights():
	for agent in ($Agents.get_children() as Array[Agent]):
		if agent.player_id != multiplayer.get_unique_id():
			continue
		if agent.in_smoke:
			continue
		for detected in agent._eyes.get_overlapping_areas():
			var par = detected.get_parent()
			if par is Agent:
				if agent == par: # of course you can see yourself
					continue
				try_see_agent(agent, par)
			else:
				try_see_element(agent, par)


func log10(x: float) -> float:
	return log(x) / log(10)


func calculate_sight_chance(spotter : Agent, spottee_pos : Vector3, visible_level : int) -> float:
	var dist = clampf(
		remap(spotter.position.distance_to(spottee_pos), 0.0, spotter.view_dist, 0.0, 1.0),
		0.0, 1.0)
	var exponent = ((1.5 * dist)/(log10(visible_level)))
	var inv_eye = 1.0/spotter.eye_strength
	return maxf(1.0/(inv_eye**exponent), 0.01)


func try_see_agent(spotter : Agent, spottee : Agent):
	if spotter.player_id == spottee.player_id: # skip your team
		return
	var instant_spot = false
	var instant_fail = false
	if spottee.selected_item > -1 and spottee.held_items[spottee.selected_item] == "box":
		if spottee.in_moving_state():
			instant_spot = true
		else:
			instant_fail = true
	var sight_chance = calculate_sight_chance(spotter, spottee.position, spottee.visible_level) * float(not instant_fail)
	if sight_chance > 0.7 or instant_spot: # seent it
		if current_game_step - spottee.step_seen < REMEMBER_TILL and spottee.step_seen > 0:
			spottee.step_seen = current_game_step
			return
		spottee.step_seen = current_game_step
		if spotter.player_id == 1:
			spottee.server_knows = true
		else:
			spottee.client_knows = true
		create_popup(GameRefs.POPUP.spotted, spottee.position, true)
		if spotter.player_id != spottee.player_id:
			spotter.sounds.spotted_agent.play()
	elif sight_chance > 1.0/3.0: # almost seent it
		if spottee.noticed > 0:
			return
		spottee.noticed = 10
		var p_offset = -0.1/sight_chance
		var x_off = randf_range(-p_offset, p_offset)
		var z_off = randf_range(-p_offset, p_offset)
		create_popup(GameRefs.POPUP.sight_unknown, spottee.position + Vector3(x_off, 0, z_off))
		spotter.sounds.glanced.play()


func try_see_element(spotter : Agent, element : Node3D):
	if element is GamePopup:
		if calculate_sight_chance(spotter, element.global_position, 120) > 0.25:
			element.disappear()
	elif element is WeaponPickup:
		if spotter.player_id == 1 and element.server_knows != true:
			element.server_knows = true
			spotter.sounds.spotted_element.play()
		elif spotter.player_id != 1 and element.client_knows != true:
			element.client_knows = true
	elif element is Grenade:
		if spotter.player_id == 1 and element.server_knows != true:
			element.server_knows = true
			spotter.sounds.spotted_agent.play()
		elif spotter.player_id != 1 and element.client_knows != true:
			element.client_knows = true
	else:
		element.visible = true
		spotter.sounds.spotted_element.play()


func determine_sounds():
	for agent in ($Agents.get_children() as Array[Agent]):
		if agent.in_incapacitated_state():
			continue # incapped agents are deaf
		for detected in agent._ears.get_overlapping_areas():
			var audio_event : GameAudioEvent = detected.get_parent()
			if agent.player_id == audio_event.player_id:
				continue # skip same team sources
			if audio_event.heard:
				continue # skip already heard sounds
			create_popup(GameRefs.POPUP.sound_unknown, audio_event.global_position)
			audio_event.play_sound()
		if multiplayer.is_server():
			match agent.state:
				Agent.States.WALK when agent.game_steps_since_execute % 40 == 0:
					create_sound_effect.rpc(agent.position, agent.player_id, 13, 0.25, 2.0, "ag_step_quiet")
				Agent.States.RUN when agent.game_steps_since_execute % 20 == 0:
					create_sound_effect.rpc(agent.position, agent.player_id, 13, 1.5, 2.75, "ag_step_loud")
				Agent.States.CROUCH_WALK when agent.game_steps_since_execute % 50 == 0:
					create_sound_effect.rpc(agent.position, agent.player_id, 13, 0.25, 2.0, "ag_step_quiet")
	for audio_event in ($AudioEvents.get_children() as Array[GameAudioEvent]):
		audio_event.update()


func determine_indicator_removals():
	for ind in $ClientsideIndicators.get_children():
		if ind is AimingIndicator or ind is MovementIndicator:
			match ind.referenced_agent.action_done:
				Agent.ActionDoneness.SUCCESS:
					ind._succeed()
				Agent.ActionDoneness.FAIL:
					ind._fail()


func _physics_process(delta: float) -> void:
	_server_progress.value = lerpf(_server_progress.value, float(server_progress), 0.2)
	_client_progress.value = lerpf(_client_progress.value, float(client_progress), 0.2)
	if game_phase == GamePhases.SELECTION:
		for selector in $HUDSelectors.get_children() as Array[AgentSelector]:
			if selector.referenced_agent == null: # the only case where the agent is null is the one where the node was destroyed by the server disconnecting
				for selector_to_free in $HUDSelectors.get_children() as Array[AgentSelector]:
					selector_to_free.queue_free()
				break
			selector.position = (
		$World/Camera3D as Camera3D).unproject_position(
				selector.referenced_agent.position)
			(selector.get_child(0) as CollisionShape2D).shape.size = Vector2(32, 32) * GameCamera.MAX_FOV/_camera.fov
	if multiplayer.is_server():
		if game_phase == GamePhases.EXECUTION:
			determine_cqc_events()
			determine_weapon_events()
			for agent in ($Agents.get_children() as Array[Agent]):
				agent._game_step(delta)
				agent.in_smoke = false
				if current_game_step - agent.step_seen == REMEMBER_TILL and agent.visible:
					if agent.player_id == 1:
						agent.client_knows = false
						create_popup.rpc_id(GameSettings.other_player_id, GameRefs.POPUP.sight_unknown, agent.position)
					else:
						agent.server_knows = false
						create_popup(GameRefs.POPUP.sight_unknown, agent.position)
				if len(agent.mark_for_drop) > 0:
					var new_drop = {
						pos_x = agent.mark_for_drop.position.x,
						pos_y = agent.mark_for_drop.position.y,
						pos_z = agent.mark_for_drop.position.z,
						server_knows = agent.player_id == 1 or $Weapons.get_node(str(agent.mark_for_drop.wep_node)).is_map_element(),
						client_knows = agent.player_id != 1 or $Weapons.get_node(str(agent.mark_for_drop.wep_node)).is_map_element(),
						wep_name = str(agent.mark_for_drop.wep_node),
					}
					pickup_spawner.spawn(new_drop)
					agent.held_weapons.erase(agent.mark_for_drop.wep_node)
					agent.mark_for_drop.clear()
				if agent.try_grab_pickup and len(agent.queued_action) > 1:
					if $Pickups.get_node_or_null(str(agent.queued_action[1])) != null:
						$Pickups.get_node(str(agent.queued_action[1])).queue_free()
					agent.try_grab_pickup = false
				if agent.state == Agent.States.DEAD and len(agent.held_weapons) > 1:
					var new_drop = {
						pos_x = agent.global_position.x + (randf() - 0.5),
						pos_y = agent.global_position.y,
						pos_z = agent.global_position.z + (randf() - 0.5),
						server_knows = agent.player_id == 1 or $Weapons.get_node(str(agent.held_weapons[1])).is_map_element(),
						client_knows = agent.player_id != 1 or $Weapons.get_node(str(agent.held_weapons[1])).is_map_element(),
						wep_name = str(agent.held_weapons[1]),
					}
					pickup_spawner.spawn(new_drop)
					agent.held_weapons.erase(new_drop.wep_name)
				if agent.mark_for_grenade_throw:
					var try_name = agent.held_weapons[agent.selected_weapon]
					while try_name in grenades_in_existence:
						try_name += "N"
					var grenade_data = {
						pos_x = agent.position.x,
						pos_y = agent.position.y,
						pos_z = agent.position.z,
						wep_name = try_name,
						wep_id = GameRefs.get_weapon_node(agent.held_weapons[agent.selected_weapon]).wep_id,
						player_id = agent.player_id,
						server_knows = agent.server_knows,
						client_knows = agent.client_knows,
						end_pos_x = agent.queued_action[1].x,
						end_pos_y = agent.queued_action[1].y,
						end_pos_z = agent.queued_action[1].z,
					}
					grenade_spawner.spawn(grenade_data)
					agent.mark_for_grenade_throw = false
			for grenade in ($Grenades.get_children() as Array[Grenade]):
				grenade._tick()
				if grenade.explode:
					match grenade.wep_id:
						"grenade_frag":
							for exploded in grenade._explosion_hitbox.get_overlapping_areas():
								var attacked : Agent = exploded.get_parent()
								if attacked.in_prone_state():
									continue # prone agents dodge explosions for Reasons™
								attacked.take_damage(2, false)
								create_sound_effect.rpc(attacked.position, attacked.player_id, 5, 0.75, 2.5, "ag_hurt")
							create_sound_effect.rpc(grenade.global_position, grenade.player_id, 10, 0.1, 5.0, "grenade_frag")
						"grenade_smoke":
							smoke_spawner.spawn({
								pos_x = grenade.position.x,
								pos_y = grenade.position.y,
								pos_z = grenade.position.z,
								wep_name = grenade.name,
							})
							create_sound_effect.rpc(grenade.global_position, grenade.player_id, 10, 0.1, 5.0, "grenade_smoke")
						"grenade_noise":
							create_sound_effect.rpc(grenade.global_position, grenade.player_id, 10, 0.1, 10.0, "grenade_frag")
					if multiplayer.is_server():
						grenades_in_existence.erase(grenade.name)
						grenade.queue_free()
			for smoke in ($Smokes.get_children() as Array[Smoke]):
				smoke._tick()
				for caught in smoke.col_area.get_overlapping_areas():
					caught.get_parent().in_smoke = true
				if smoke.lifetime > 205:
					smoke.queue_free()
			for pickup in ($Pickups.get_children() as Array[WeaponPickup]):
				pickup._animate(delta)
			current_game_step += 1
			determine_sights()
			determine_sounds()
			determine_indicator_removals()
			for agent in ($Agents.get_children() as Array[Agent]):
				if agent.action_done == Agent.ActionDoneness.NOT_DONE:
					return
			_update_game_phase.rpc(GamePhases.SELECTION)
		elif game_phase == GamePhases.COMPLETION:
			for ag in ($Agents.get_children() as Array[Agent]):
				ag.visible = true
				ag.queued_action.clear()
				if ag.in_standing_state():
					ag.state = Agent.States.STAND
				elif ag.in_crouching_state():
					ag.state = Agent.States.CROUCH
				elif ag.in_prone_state():
					ag.state = Agent.States.PRONE
				ag._game_step(delta, true)


func _process(_d: float) -> void:
	if Input.is_action_just_pressed("pause_menu"):
		open_pause_menu()


func server_populate_variables(): #TODO
	# server's agents
	var data = {
		player_id = 1,
		agent_stats = Lobby.players[1].agents[GameSettings.selected_agents[0]],
		pos_x = game_map.agent_spawn_server_1.position.x,
		pos_y = game_map.agent_spawn_server_1.position.y - 0.666,
		pos_z = game_map.agent_spawn_server_1.position.z,
		rot_y = game_map.agent_spawn_server_1.rotation.y,
	}
	ag_spawner.spawn(data)
	if len(GameSettings.selected_agents) > 1:
		data.agent_stats = Lobby.players[1].agents[GameSettings.selected_agents[1]]
		data.pos_x = game_map.agent_spawn_server_2.position.x
		data.pos_y = game_map.agent_spawn_server_2.position.y - 0.666
		data.pos_z = game_map.agent_spawn_server_2.position.z
		data.rot_y = game_map.agent_spawn_server_2.rotation.y
		ag_spawner.spawn(data)
	if len(GameSettings.selected_agents) > 2:
		data.agent_stats = Lobby.players[1].agents[GameSettings.selected_agents[2]]
		data.pos_x = game_map.agent_spawn_server_3.position.x
		data.pos_y = game_map.agent_spawn_server_3.position.y - 0.666
		data.pos_z = game_map.agent_spawn_server_3.position.z
		data.rot_y = game_map.agent_spawn_server_3.rotation.y
		ag_spawner.spawn(data)
	if len(GameSettings.selected_agents) > 3:
		data.agent_stats = Lobby.players[1].agents[GameSettings.selected_agents[3]]
		data.pos_x = game_map.agent_spawn_server_4.position.x
		data.pos_y = game_map.agent_spawn_server_4.position.y - 0.666
		data.pos_z = game_map.agent_spawn_server_4.position.z
		data.rot_y = game_map.agent_spawn_server_4.rotation.y
		ag_spawner.spawn(data)
	# client's agents
	data.player_id = GameSettings.other_player_id
	data.agent_stats = Lobby.players[data.player_id].agents[GameSettings.client_selected_agents[0]]
	data.pos_x = game_map.agent_spawn_client_1.position.x
	data.pos_y = game_map.agent_spawn_client_1.position.y - 0.666
	data.pos_z = game_map.agent_spawn_client_1.position.z
	data.rot_y = game_map.agent_spawn_client_1.rotation.y
	ag_spawner.spawn(data)
	if len(GameSettings.client_selected_agents) > 1:
		data.agent_stats = Lobby.players[data.player_id].agents[GameSettings.client_selected_agents[1]]
		data.pos_x = game_map.agent_spawn_client_2.position.x
		data.pos_y = game_map.agent_spawn_client_2.position.y - 0.666
		data.pos_z = game_map.agent_spawn_client_2.position.z
		data.rot_y = game_map.agent_spawn_client_2.rotation.y
		ag_spawner.spawn(data)
	if len(GameSettings.client_selected_agents) > 2:
		data.agent_stats = Lobby.players[data.player_id].agents[GameSettings.client_selected_agents[2]]
		data.pos_x = game_map.agent_spawn_client_3.position.x
		data.pos_y = game_map.agent_spawn_client_3.position.y - 0.666
		data.pos_z = game_map.agent_spawn_client_3.position.z
		data.rot_y = game_map.agent_spawn_client_3.rotation.y
		ag_spawner.spawn(data)
	if len(GameSettings.client_selected_agents) > 3:
		data.agent_stats = Lobby.players[data.player_id].agents[GameSettings.client_selected_agents[3]]
		data.pos_x = game_map.agent_spawn_client_4.position.x
		data.pos_y = game_map.agent_spawn_client_4.position.y - 0.666
		data.pos_z = game_map.agent_spawn_client_4.position.z
		data.rot_y = game_map.agent_spawn_client_4.rotation.y
		ag_spawner.spawn(data)


func append_action_timeline(agent : Agent):
	if not action_timeline.has(current_game_step):
		action_timeline[current_game_step] = {}
	action_timeline[current_game_step][agent.name] = agent.queued_action


@rpc("call_local")
func ping():
	print("{0}: pong!".format([multiplayer.multiplayer_peer.get_unique_id()]))


func create_agent(data) -> Agent: #TODO
	var new_agent : Agent = agent_scene.instantiate()
	new_agent.name = str(data.player_id) + "_" + str(data.agent_stats.name)

	new_agent.position = Vector3(data.pos_x, data.pos_y, data.pos_z)
	new_agent.rotation.y = data.rot_y
	#new_agent.set_multiplayer_authority(data.player_id)
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
		var new_small_hud = hud_agent_small_scene.instantiate()
		_quick_views.add_child(new_small_hud)
		new_small_hud._health_bar.max_value = data.agent_stats.health
		new_small_hud._stun_health_bar.max_value = data.agent_stats.health / 2
		new_small_hud.ref_ag = new_agent
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


@rpc()
func create_agent_selector(agent_name : String):
	var agent : Agent = $Agents.get_node(agent_name)
	# check if selector already exists
	for s in ($HUDSelectors.get_children() as Array[AgentSelector]):
		if s.referenced_agent == agent:
			return
	var new_selector = agent_selector_scene.instantiate()
	new_selector.referenced_agent = agent
	new_selector.agent_selected.connect(_hud_agent_details_actions)
	$HUDSelectors.add_child(new_selector)


func return_attacked(attacker : Agent, location : Vector3):
	var space_state = get_world_3d().direct_space_state
	var origin = attacker._body.global_position
	location.y = origin.y
	var query = PhysicsRayQueryParameters3D.create(origin, location)
	query.exclude = [attacker._body]
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.hit_from_inside = true
	var result = space_state.intersect_ray(query)
	return [(result.get("collider", null) as Area3D), result.get("position", location)]


func determine_cqc_events():
	var cqc_actors = {}
	for agent in ($Agents.get_children() as Array[Agent]):
		if agent.state != Agent.States.CQC_GRAB:
			continue
		cqc_actors[agent] = return_attacked(agent, agent.queued_action[1])[0]
	for grabber in (cqc_actors.keys() as Array[Agent]):
		grabber.state = Agent.States.USING_WEAPON
		if cqc_actors[grabber] == null:
			continue
		if not (cqc_actors[grabber] as Area3D).get_parent() is Agent:
			grabber._anim_state.travel("B_Stand_Attack_Whiff")
			continue
		var grabbee : Agent = (cqc_actors[grabber] as Area3D).get_parent()
		if grabbee in cqc_actors and grabber.player_id == 1: #client wins tiebreakers
			grabber._anim_state.travel("B_Stand_Attack_Whiff")
			continue
		if grabber.player_id == grabbee.player_id: # don't grab your friends
			grabber._anim_state.travel("B_Stand_Attack_Whiff")
			continue
		if grabbee.in_incapacitated_state(): # don't grab people who're already on the ground
			grabber._anim_state.travel("B_Stand_Attack_Whiff")
			continue
		if grabbee.selected_item > -1 and grabbee.held_items[grabbee.selected_item] == "box":
			grabber._anim_state.travel("B_Stand_Attack_Whiff")  # don't grab boxes
			continue
		if grabbee.ungrabbable: # don't grab the ungrabbable
			grabber._anim_state.travel("B_Stand_Attack_Whiff")
			continue
		grabber._anim_state.travel("B_Stand_Attack_Slam")
		grabbee.grabbing_agent = grabber
		if multiplayer.is_server():
			grabbee.take_damage(3, true)
		grabbee.step_seen = current_game_step

func slide_end_pos(start_pos : Vector3, end_pos : Vector3, change : float):
	return end_pos + start_pos.direction_to(end_pos).rotated(Vector3.DOWN, PI/2) * change

func determine_weapon_events():
	var attackers = {}
	for agent in ($Agents.get_children() as Array[Agent]):
		if agent.state != Agent.States.FIRE_GUN:
			continue
		GameRefs.get_weapon_node(agent.held_weapons[agent.selected_weapon]).loaded_ammo -= 1
		match GameRefs.get_weapon_node(agent.held_weapons[agent.selected_weapon]).wep_id:
			"pistol":
				attackers[agent] = [return_attacked(agent, agent.queued_action[1])]
				if multiplayer.is_server():
					create_sound_effect.rpc(agent.position, agent.player_id, 10, 0.25, 0.5, "pistol")
			"rifle":
				attackers[agent] = [return_attacked(agent, slide_end_pos(agent._body.global_position, agent.queued_action[1], 0.2)),return_attacked(agent, slide_end_pos(agent._body.global_position, agent.queued_action[1], -0.2)),]
				if multiplayer.is_server():
					create_sound_effect.rpc(agent.position, agent.player_id, 10, 0.5, 1.5, "rifle")
			"shotgun":
				attackers[agent] = [
					return_attacked(
						agent,
						slide_end_pos(agent._body.global_position, agent.queued_action[1], 1.0)
						),
					return_attacked(
						agent,
						agent.queued_action[1]
						),
					return_attacked(
						agent,
						slide_end_pos(agent._body.global_position, agent.queued_action[1], -1.0)
						),
					]
				if multiplayer.is_server():
					create_sound_effect.rpc(agent.position, agent.player_id, 15, 2.25, 3.5, "shotgun")
	for attacker in (attackers.keys() as Array[Agent]):
		attacker.state = Agent.States.USING_WEAPON
		for hit in attackers[attacker]:
			if hit[0] == null: # hit a wall, make a sound event on the wall
				if multiplayer.is_server():
					create_sound_effect.rpc(hit[1], attacker.player_id, 4, 0.5, 2, "projectile_bounce")
			else:
				if not (hit[0] as Area3D).get_parent() is Agent: # still hit a wall
					if multiplayer.is_server():
						create_sound_effect.rpc(hit[1], attacker.player_id, 4, 0.5, 2, "projectile_bounce")
				else: # actually hit an agent
					var attacked : Agent = (hit[0] as Area3D).get_parent()
					if attacker.player_id == attacked.player_id:
						continue # same team can block bullets but won't take damage
					if attacked.stun_time > 0:
						continue # skip already attacked agents
					if attacked.in_prone_state() or attacked.state == Agent.States.DEAD:
						continue # skip prone agents
					if multiplayer.is_server():
						attacked.take_damage(GameRefs.get_held_weapon_attribute(attacker, attacker.selected_weapon, "damage"), false)
						create_sound_effect.rpc(attacked.position, attacked.player_id, 5, 0.75, 2.5, "ag_hurt")


func _hud_agent_details_actions(agent_selector : AgentSelector):
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
	for small_hud in ($HUDBase/QuickViews.get_children()):
		if small_hud.ref_ag == agent:
			small_hud.flash = 1.0
	_radial_menu.referenced_agent = agent
	_radial_menu.position = agent_selector.position
	_radial_menu.init_menu()
	_execute_button.visible = false
	_execute_button.disabled = true


func hide_hud():
	var twe = create_tween()
	twe.set_parallel(true)
	twe.set_trans(Tween.TRANS_CUBIC)
	twe.tween_property(_execute_button, "position:y", 970, 0.25).from(825)
	#twe.tween_property(_quick_views, "position:y", 920, 0.25).from(712)
	twe.tween_property(_ag_insts, "position:x", 1638, 0.25).from(1059)


func show_hud():
	var twe = create_tween()
	twe.set_parallel(true)
	twe.set_trans(Tween.TRANS_SINE)
	twe.tween_property(_execute_button, "position:y", 825, 0.25).from(970)
	#twe.tween_property(_quick_views, "position:y", 712, 0.25).from(920)
	twe.tween_property(_ag_insts, "position:x", 1059, 0.25).from(1638)


func _on_radial_menu_decision_made(decision_array: Array) -> void:
	var ref_ag : Agent = _radial_menu.referenced_agent
	_radial_menu.referenced_agent = null
	if $ClientsideIndicators.get_node_or_null(String(ref_ag.name)): # remove prev indicator
		$ClientsideIndicators.get_node(String(ref_ag.name))._neutral()
		$ClientsideIndicators.get_node(String(ref_ag.name)).name += "_neutralling"
	ref_ag.queued_action = decision_array
	var final_text_string := ""
	var clean_name = GameRefs.extract_agent_name(ref_ag.name)
	match decision_array[0]:
		Agent.GameActions.GO_STAND:
			final_text_string = "{0}: Stand Up".format([clean_name])
		Agent.GameActions.GO_CROUCH:
			final_text_string = "{0}: Crouch".format([clean_name])
		Agent.GameActions.GO_PRONE:
			final_text_string = "{0}: Go Prone".format([clean_name])
		Agent.GameActions.LOOK_AROUND:
			final_text_string = "{0}: Survey Area".format([clean_name])
		Agent.GameActions.CHANGE_ITEM:
			final_text_string = "{0}: Equip ".format([clean_name])
			if decision_array[1] == -1:
				final_text_string = "{0}: Unequip Item".format([clean_name])
			else:
				final_text_string += GameRefs.ITM[ref_ag.held_items[decision_array[1]]].name
		Agent.GameActions.CHANGE_WEAPON:
			final_text_string = "{0}: Switch to {1}".format([
				clean_name, GameRefs.get_held_weapon_attribute(ref_ag, decision_array[1], "name")])
		Agent.GameActions.PICK_UP_WEAPON:
			final_text_string = "{0}: Pick up {1}".format([
				clean_name, GameRefs.get_pickup_attribute(GameRefs.get_pickup_node(decision_array[1]), "name")])
		Agent.GameActions.DROP_WEAPON:
			final_text_string = "{0}: Drop {1}".format([
				clean_name, GameRefs.get_held_weapon_attribute(ref_ag, decision_array[1], "name")])
		Agent.GameActions.RELOAD_WEAPON:
			final_text_string = "{0}: Reload {1}".format([
				clean_name, GameRefs.get_held_weapon_attribute(ref_ag, decision_array[1], "name")])
		Agent.GameActions.HALT:
			final_text_string = "{0}: Stop ".format([clean_name])
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
	if ref_ag.owned():
		ref_ag.action_text = final_text_string
	update_text()
	_execute_button.visible = true
	_execute_button.disabled = false


func _on_radial_menu_movement_decision_made(decision_array: Array) -> void:
	var ref_ag : Agent = _radial_menu.referenced_agent
	_radial_menu.referenced_agent = null
	if $ClientsideIndicators.get_node_or_null(String(ref_ag.name)):
		$ClientsideIndicators.get_node(String(ref_ag.name))._neutral()
		$ClientsideIndicators.get_node(String(ref_ag.name)).name += "_neutralling"
	ref_ag.queued_action = decision_array
	selection_step = SelectionSteps.MOVEMENT
	var new_indicator = movement_icon_scene.instantiate()
	new_indicator.referenced_agent = ref_ag
	new_indicator.name = ref_ag.name
	$ClientsideIndicators.add_child(new_indicator)
	await new_indicator.indicator_placed
	selection_step = SelectionSteps.BASE
	decision_array.append(new_indicator.position)
	var final_text_string := ""
	var clean_name = GameRefs.extract_agent_name(ref_ag.name)
	match decision_array[0]:
		Agent.GameActions.RUN_TO_POS:
			final_text_string = "{0}: Run ".format([clean_name])
		Agent.GameActions.WALK_TO_POS:
			final_text_string = "{0}: Walk ".format([clean_name])
		Agent.GameActions.CROUCH_WALK_TO_POS:
			final_text_string = "{0}: Sneak ".format([clean_name])
		Agent.GameActions.CRAWL_TO_POS:
			final_text_string = "{0}: Crawl ".format([clean_name])
	final_text_string += "to New Position"
	if ref_ag.owned():
		ref_ag.action_text = final_text_string
	update_text()
	_execute_button.visible = true
	_execute_button.disabled = false


func _on_radial_menu_aiming_decision_made(decision_array: Array) -> void:
	var ref_ag : Agent = _radial_menu.referenced_agent
	_radial_menu.referenced_agent = null
	if $ClientsideIndicators.get_node_or_null(String(ref_ag.name)):
		$ClientsideIndicators.get_node(String(ref_ag.name))._neutral()
		$ClientsideIndicators.get_node(String(ref_ag.name)).name += "_neutralling"
	ref_ag.queued_action = decision_array
	selection_step = SelectionSteps.AIMING
	var new_indicator = aiming_icon_scene.instantiate()
	new_indicator.referenced_agent = ref_ag
	new_indicator.name = ref_ag.name
	$ClientsideIndicators.add_child(new_indicator)
	await new_indicator.indicator_placed
	selection_step = SelectionSteps.BASE
	decision_array.append(new_indicator._indicator.global_position)
	var final_text_string := ""
	var clean_name = GameRefs.extract_agent_name(ref_ag.name)
	match decision_array[0]:
		Agent.GameActions.LOOK_AROUND:
			final_text_string = "{0}: Look at Position".format([clean_name])
		Agent.GameActions.USE_WEAPON:
			final_text_string = "{0}: Use {1} at Position".format(
				[clean_name, GameRefs.get_held_weapon_attribute(ref_ag, ref_ag.selected_weapon, "name")])
		Agent.GameActions.DROP_WEAPON:
			final_text_string = "{0}: Drop {1}".format([
				clean_name, GameRefs.get_held_weapon_attribute(ref_ag, decision_array[1], "name")])
	if ref_ag.owned():
		ref_ag.action_text = final_text_string
	update_text()
	_execute_button.visible = true
	_execute_button.disabled = false


func _on_radial_menu_no_decision_made() -> void:
	_execute_button.visible = true
	_execute_button.disabled = false


@rpc("authority", "call_local")
func selection_ui():
	_round_ended.play()
	_phase_label.text = "SELECT ACTIONS"
	_execute_button.disabled = false
	_execute_button.text = "EXECUTE INSTRUCTIONS"
	show_hud()

@rpc("authority", "call_local")
func execution_ui():
	$HUDBase/HurryUp.visible = false
	update_text()
	_phase_label.text = "EXECUTING ACTIONS..."

# called by the server to handle exfiltrations
func _exfiltrate_agents():
	match server_progress:
		ProgressParts.ITEM_HELD:
			var exfil_available = false
			for detect in game_map.server_exfiltrate_zone.get_overlapping_areas():
				var agent : Agent = detect.get_parent()
				if agent.in_incapacitated_state():
					continue
				for weap in agent.held_weapons:
					if (weap as String).begins_with("map_"):
						exfil_available = true
						break
				if exfil_available:
					break
			if exfil_available:
				for detect in game_map.server_exfiltrate_zone.get_overlapping_areas():
					var agent : Agent = detect.get_parent()
					if agent.in_incapacitated_state():
						continue
					exfiltration_queue.append(agent)
		ProgressParts.OBJECTIVE_COMPLETE:
			for detect in game_map.server_exfiltrate_zone.get_overlapping_areas():
				var agent : Agent = detect.get_parent()
				if agent.in_incapacitated_state():
					continue
				exfiltration_queue.append(agent)
	match client_progress:
		ProgressParts.ITEM_HELD:
			var exfil_available = false
			for detect in game_map.client_exfiltrate_zone.get_overlapping_areas():
				var agent : Agent = detect.get_parent()
				if agent.state == Agent.States.DEAD:
					continue
				for weap in agent.held_weapons:
					if (weap as String).begins_with("map_"):
						exfil_available = true
						break
				if exfil_available:
					break
			if exfil_available:
				for detect in game_map.client_exfiltrate_zone.get_overlapping_areas():
					var agent : Agent = detect.get_parent()
					if agent.in_incapacitated_state():
						continue
					exfiltration_queue.append(agent)
		ProgressParts.OBJECTIVE_COMPLETE:
			for detect in game_map.client_exfiltrate_zone.get_overlapping_areas():
				var agent : Agent = detect.get_parent()
				if agent.in_incapacitated_state():
					continue
				exfiltration_queue.append(agent)
	for agent in exfiltration_queue:
		agent.exfiltrate()

@rpc()
func create_end_screen():
	$PauseMenu/ColorRect/CurrentPhase.text = "EXIT"
	open_pause_menu()
	$PauseMenu/ColorRect/VBoxContainer/NoForfeit.visible = false
	$PauseMenu/ColorRect/VBoxContainer/NoForfeit.disabled = true


# called by the server to update the game state and rpc things to the client
func _update_game_phase(new_phase: GamePhases, check_incap := true):
	#await get_tree().create_timer(0.1).timeout
	game_phase = new_phase
	match game_phase:
		# create/direct ui for both players to set up selection mode
		GamePhases.SELECTION:
			for ag in ($Agents.get_children() as Array[Agent]):
				ag.action_done = Agent.ActionDoneness.NOT_DONE
				ag.ungrabbable = false
				ag.queued_action.clear()
				if not ag.in_incapacitated_state():
					if ag.owned():
						create_agent_selector(ag.name)
						ag.flash_outline(Color.ORCHID)
					else:
						create_agent_selector.rpc_id(GameSettings.other_player_id, ag.name)
						ag.flash_outline.rpc_id(GameSettings.other_player_id, Color.ORCHID)
			selection_ui.rpc()
		# hide & disable selection mode stuff, start agent actions
		GamePhases.EXECUTION:
			for agent in ($Agents.get_children() as Array[Agent]):
				agent.action_text = ""
			server_ready_bool = false
			client_ready_bool = false
			# populate agents with actions, as well as action_timeline
			for agent in ($Agents.get_children() as Array[Agent]):
				append_action_timeline(agent)
				agent.perform_action()
			execution_ui.rpc()
		# determine progress made by agents, choose winner if applicable
		GamePhases.COMPLETION:
			if sent_reward:
				return
			# who's escaping now
			_exfiltrate_agents()
			# has a team fully died
			var server_team_dead = true
			var client_team_dead = true
			for ag in ($Agents.get_children() as Array[Agent]):
				if ag.state != Agent.States.DEAD:
					if ag.player_id == 1:
						server_team_dead = false
					else:
						client_team_dead = false
			if server_team_dead and not client_team_dead:
				create_toast_update.rpc(GameRefs.TXT.any_t_dead, GameRefs.TXT.any_y_dead, false)
				reward_team.rpc_id(GameSettings.other_player_id, GameSettings.other_player_id)
				victory_jingle.rpc()
				failure_jingle()
				sent_reward = true
				# handle client win
			elif client_team_dead and not server_team_dead:
				create_toast_update.rpc(GameRefs.TXT.any_y_dead, GameRefs.TXT.any_t_dead, false)
				reward_team(1)
				victory_jingle()
				failure_jingle.rpc()
				sent_reward = true
				# handle server win
			elif server_team_dead and client_team_dead:
				create_toast_update.rpc(GameRefs.TXT.any_a_dead, GameRefs.TXT.any_a_dead, false)
				failure_jingle()
				failure_jingle.rpc()
				sent_reward = true
			# how's the objective looking
			_track_objective_completion()
			if server_progress == ProgressParts.SURVIVORS_EXFILTRATED:
				reward_team(1)
				victory_jingle()
				failure_jingle.rpc()
				sent_reward = true
			if client_progress == ProgressParts.SURVIVORS_EXFILTRATED:
				reward_team.rpc_id(GameSettings.other_player_id, GameSettings.other_player_id)
				victory_jingle.rpc()
				failure_jingle()
				sent_reward = true
			if sent_reward:
				save_replay.rpc(str(int(Time.get_unix_time_from_system())))
				create_toast_update.rpc("GAME OVER", "GAME OVER", true, Color.INDIGO - Color(0, 0, 0, 1 - 0.212))
				animate_fade.rpc()
				create_end_screen.rpc()





@rpc("authority", "call_local")
func save_replay(end_time):
	action_timeline[current_game_step] = "END"
	if DirAccess.open("user://replays") == null:
		DirAccess.make_dir_absolute("user://replays")
	var new_replay = FileAccess.open("user://replays/" + start_time + "_" + end_time + ".mstr", FileAccess.WRITE)
	new_replay.store_string(JSON.stringify(action_timeline))


func _track_objective_completion():
	match game_map.objective:
		GameMap.Objectives.CAPTURE_CENTRAL_FLAG:
			of_comp()
		#GameMap.Objectives.CAPTURE_ENEMY_FLAG:
			#enemy_flag_completion()


func check_agents_for_weapon(server_team : bool, item_name : String) -> bool:
	for ag in ($Agents.get_children() as Array[Agent]):
		if ag.player_id != 1 and server_team or ag.player_id == 1 and not server_team:
			continue
		if ag.state == Agent.States.DEAD:
			continue
		if item_name in ag.held_weapons:
			return true
	return false


func check_weapon_holder_exfil(server_team : bool, item_name : String) -> bool:
	for ag in ($Agents.get_children() as Array[Agent]):
		if ag.player_id != 1 and server_team or ag.player_id == 1 and not server_team:
			continue
		if ag.state == Agent.States.DEAD:
			continue
		if ag.state != Agent.States.EXFILTRATED:
			continue
		if item_name in ag.held_weapons:
			return true
	return false


# only called by server, owned is used here to check if agent is on server team
func _check_full_team_exfil_or_dead(server_team : bool):
	var count = 0
	for ag in ($Agents.get_children() as Array[Agent]):
		if ag.owned() and not server_team or not ag.owned() and server_team:
			continue
		count += 1
		if ag.state in [Agent.States.EXFILTRATED, Agent.States.DEAD]:
			count -= 1
	return count == 0


func of_comp():
	of_comp_server()
	of_comp_client()

func of_comp_server():
	match server_progress:
		ProgressParts.INTRO:
			create_toast_update.rpc(GameRefs.TXT.of_intro, GameRefs.TXT.of_intro, true)
			server_progress = ProgressParts.NO_ADVANTAGE
		ProgressParts.NO_ADVANTAGE: # no one has the flag
			if not check_agents_for_weapon(true, "map_flag_center"):
				return
			if not check_weapon_holder_exfil(true, "map_flag_center"):
				create_toast_update.rpc(GameRefs.TXT.of_y_get, GameRefs.TXT.of_t_get, true)
				server_progress = ProgressParts.ITEM_HELD
				return
			if not _check_full_team_exfil_or_dead(true):
				create_toast_update.rpc(GameRefs.TXT.of_cap_agents_remain, GameRefs.TXT.of_cap_agents_remain, true)
				server_progress = ProgressParts.OBJECTIVE_COMPLETE
				return
			create_toast_update.rpc(GameRefs.TXT.of_y_cap_left, GameRefs.TXT.of_t_cap_left, true)
			server_progress = ProgressParts.SURVIVORS_EXFILTRATED
			return
		ProgressParts.ITEM_HELD: # the server team has the flag
			if not check_agents_for_weapon(true, "map_flag_center"):
				create_toast_update.rpc(GameRefs.TXT.of_y_lost, GameRefs.TXT.of_t_lost, true)
				server_progress = ProgressParts.NO_ADVANTAGE
				return
			if check_weapon_holder_exfil(true, "map_flag_center"):
				if not _check_full_team_exfil_or_dead(true):
					create_toast_update.rpc(GameRefs.TXT.of_cap_agents_remain, GameRefs.TXT.of_cap_agents_remain, true)
					server_progress = ProgressParts.OBJECTIVE_COMPLETE
					return
				create_toast_update.rpc(GameRefs.TXT.of_y_cap_left, GameRefs.TXT.of_t_cap_left, true)
				server_progress = ProgressParts.SURVIVORS_EXFILTRATED
				return
		ProgressParts.OBJECTIVE_COMPLETE: # a server team member has escaped with the flag
			if _check_full_team_exfil_or_dead(true):
				create_toast_update.rpc(GameRefs.TXT.mission_success, GameRefs.TXT.mission_failure, true)
				server_progress = ProgressParts.SURVIVORS_EXFILTRATED


func of_comp_client():
	match client_progress:
		ProgressParts.INTRO:
			client_progress = ProgressParts.NO_ADVANTAGE
		ProgressParts.NO_ADVANTAGE: # no one has the flag
			if not check_agents_for_weapon(false, "map_flag_center"):
				return
			if not check_weapon_holder_exfil(false, "map_flag_center"):
				create_toast_update.rpc(GameRefs.TXT.of_t_get, GameRefs.TXT.of_y_get, true)
				client_progress = ProgressParts.ITEM_HELD
				return
			if not _check_full_team_exfil_or_dead(false):
				create_toast_update.rpc(GameRefs.TXT.of_cap_agents_remain, GameRefs.TXT.of_cap_agents_remain, true)
				client_progress = ProgressParts.OBJECTIVE_COMPLETE
				return
			create_toast_update.rpc(GameRefs.TXT.of_t_cap_left, GameRefs.TXT.of_y_cap_left, true)
			client_progress = ProgressParts.SURVIVORS_EXFILTRATED
			return
		ProgressParts.ITEM_HELD: # the client team has the flag
			if not check_agents_for_weapon(false, "map_flag_center"):
				create_toast_update.rpc(GameRefs.TXT.of_t_lost, GameRefs.TXT.of_y_lost, true)
				client_progress = ProgressParts.NO_ADVANTAGE
				return
			if check_weapon_holder_exfil(false, "map_flag_center"):
				if not _check_full_team_exfil_or_dead(false):
					create_toast_update.rpc(GameRefs.TXT.of_cap_agents_remain, GameRefs.TXT.of_cap_agents_remain, true)
					client_progress = ProgressParts.OBJECTIVE_COMPLETE
					return
				create_toast_update.rpc(GameRefs.TXT.of_t_cap_left, GameRefs.TXT.of_y_cap_left, true)
				client_progress = ProgressParts.SURVIVORS_EXFILTRATED
				return
		ProgressParts.OBJECTIVE_COMPLETE: # a client team member has escaped with the flag
			if _check_full_team_exfil_or_dead(false):
				create_toast_update.rpc(GameRefs.TXT.mission_failure, GameRefs.TXT.mission_success, true)
				client_progress = ProgressParts.SURVIVORS_EXFILTRATED



@rpc("authority", "call_local")
func create_toast_update(server_text : String, client_text : String, add_sound_effect : bool, color := Color(0.565, 0, 0.565, 0.212)):
	var new_toast : ToastMessage = toast_scene.instantiate()
	new_toast.input_text = server_text if multiplayer.get_unique_id() else client_text
	new_toast.color = color
	$HUDToasts/Toasts.add_child(new_toast)
	if add_sound_effect:
		_round_update.play()
		pass


func player_quits(_peer_id):
	if game_phase == GamePhases.COMPLETION or server_progress > ProgressParts.NO_ADVANTAGE or client_progress > ProgressParts.NO_ADVANTAGE:
		return
	create_toast_update(GameRefs.TXT.forfeit, GameRefs.TXT.forfeit, false)
	$FadeOut/ColorRect/AnimatedSprite2D.play("victory")
	animate_fade(true)
	_update_game_phase(GamePhases.COMPLETION)


@rpc("authority", "call_remote", "reliable")
func victory_jingle():
	$Music/InProgress.stop()
	$Music/Victory.play()
	$FadeOut/ColorRect/AnimatedSprite2D.play("victory")


@rpc("authority", "call_remote", "reliable")
func failure_jingle():
	$Music/InProgress.stop()
	$Music/Failure.play()
	$FadeOut/ColorRect/AnimatedSprite2D.play("failure")




@rpc("authority", "reliable")
func reward_team(team_id):
	for ag in ($Agents.get_children() as Array[Agent]):
		if ag.player_id != team_id: # pick the right team
			continue
		if ag.state == Agent.States.DEAD: # only the survivors
			continue
		var ag_name_local = ag.name.split("_", true, 1)[1]
		GameSettings.winning_agents.append(ag_name_local)


@rpc("authority", "call_local")
func animate_fade(in_out := true):
	var twe := create_tween()
	if in_out:
		twe.tween_property($FadeOut/ColorRect, "modulate", Color.WHITE, 1.5).from(Color.TRANSPARENT)
	else:
		twe.tween_property($FadeOut/ColorRect, "modulate", Color.TRANSPARENT, 1.5).from(Color.WHITE)


@rpc()
func nag_player():
	$HUDBase/HurryUp.visible = true


@rpc("any_peer", "call_remote", "reliable")
func player_is_ready(caller_id):
	if caller_id == 1:
		server_ready_bool = true
		if not client_ready_bool:
			nag_player.rpc_id(GameSettings.other_player_id)
	else:
		client_ready_bool = true
		if not server_ready_bool:
			nag_player()
	if server_ready_bool and client_ready_bool:
		_update_game_phase(GamePhases.EXECUTION)


func _on_execute_pressed() -> void:
	_actions_submitted.play()
	_execute_button.disabled = true
	_execute_button.text = "WAITING FOR OPPONENT"
	for selector in $HUDSelectors.get_children():
		selector.queue_free()
	_radial_menu.button_collapse_animation()
	hide_hud()
	if multiplayer.is_server():
		player_is_ready(1)
	player_is_ready.rpc_id(1, multiplayer.get_unique_id())


# called by server after cold boot finishes to actually start the game
func _on_cold_boot_timer_timeout() -> void:
	if not multiplayer.is_server():
		return
	animate_fade.rpc(false)
	_update_game_phase(GamePhases.SELECTION, false)
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


func _on_pickup_spawner_despawned(node: Node) -> void:
	node.queue_free()


func _on_yes_forfeit_pressed() -> void:
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
	save_replay(str(int(Time.get_unix_time_from_system())))
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _on_no_forfeit_pressed() -> void:
	close_pause_menu()
