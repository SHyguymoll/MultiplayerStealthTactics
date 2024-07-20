class_name Game
extends Node3D

var agent_scene = preload("res://scenes/agent.tscn")
var agent_selector_scene = preload("res://scenes/agent_selector.tscn")
var hud_agent_small_scene = preload("res://scenes/hud_agent_small.tscn")
var movement_icon_scene = preload("res://scenes/game_movement_indicator.tscn")
var aiming_icon_scene = preload("res://scenes/game_aiming_indicator.tscn")
var tracking_raycast3d_scene = preload("res://scenes/tracking_raycast3d.tscn")
var popup_scene = preload("res://scenes/game_popup.tscn")
var audio_event_scene = preload("res://scenes/game_audio_event.tscn")

var server_ready_bool := false
var client_ready_bool := false

@export var action_timeline := {

}
var current_game_step := 0

enum GamePhases {
	SELECTION,
	EXECUTION,
}
@export var game_phase : GamePhases = GamePhases.SELECTION
enum SelectionSteps {
	BASE,
	MOVEMENT,
	AIMING,
}
var selection_step : SelectionSteps = SelectionSteps.BASE


@export var game_map : GameMap
@onready var _camera : GameCamera = $World/Camera3D
@onready var ag_spawner : MultiplayerSpawner = $AgentSpawner

@onready var _quick_views : HBoxContainer = $HUDBase/QuickViews
@onready var _radial_menu = $HUDSelected/RadialMenu
@onready var _execute_button : Button = $HUDBase/Execute
@onready var _phase_label : Label = $HUDBase/CurrentPhase
@onready var _ag_insts : Label = $HUDBase/AgentInstructions

@onready var _round_update : AudioStreamPlayer = $SoundEffects/RoundUpdate
@onready var _round_ended : AudioStreamPlayer = $SoundEffects/RoundEnded
@onready var _actions_submitted : AudioStreamPlayer = $SoundEffects/ActionsSubmitted

func _ready():
	# Preconfigure game.
	_radial_menu.visible = false
	ag_spawner.spawn_function = create_agent
	multiplayer.multiplayer_peer = Lobby.multiplayer.multiplayer_peer
	Lobby.player_loaded.rpc_id(1) # Tell the server that this peer has loaded.


# Called only on the server.
func start_game():
	# All peers are ready to receive RPCs in this scene.
	await get_tree().create_timer(0.25).timeout #...after waiting for them to completely load in
	ping.rpc()
	server_populate_variables()
	force_camera.rpc_id(GameSettings.other_player_id, (game_map.agent_spawn_client_1.position + game_map.agent_spawn_client_2.position + game_map.agent_spawn_client_3.position + game_map.agent_spawn_client_4.position)/4, 20)
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


func create_sound_effect(location : Vector3, player_id : int, lifetime : int, min_rad : float, max_rad : float, sound_id : String) -> void: #TODO
	var new_audio_event : GameAudioEvent = audio_event_scene.instantiate()
	new_audio_event.position = location
	new_audio_event.player_id = player_id
	new_audio_event.max_radius = max_rad
	new_audio_event.min_radius = min_rad
	new_audio_event.lifetime = lifetime
	new_audio_event.max_lifetime = lifetime
	new_audio_event.selected_audio = sound_id
	$AudioEvents.add_child(new_audio_event)


func create_popup(texture : Texture2D, location : Vector3, fleeting : bool = false) -> void: #TODO
	var new_popup : GamePopup = popup_scene.instantiate()
	new_popup.texture = texture
	new_popup.position = location
	$Popups.add_child(new_popup)
	if fleeting:
		new_popup.disappear()



func update_text() -> void:
	_ag_insts.text = ""
	for agent in ($Agents.get_children() as Array[Agent]):
		if agent.is_multiplayer_authority():
			_ag_insts.text += agent.action_text + "\n"

func determine_sights():
	for agent in ($Agents.get_children() as Array[Agent]):
		if not agent.is_multiplayer_authority():
			continue
		var previously_detected = agent.detected.duplicate()
		for detected in agent._eyes.get_overlapping_areas():
			var par = detected.get_parent()
			if par in previously_detected:
				previously_detected.erase(par)
			if par is Agent:
				if agent == par: # of course you can see yourself
					continue
				try_see_agent(agent, par)
			else:
				try_see_element(agent, par)
		for to_remove in previously_detected:
			pass

		# remove lost known
		# add found unknown
		# add found known
		pass


func calculate_sight_chance(spotter : Agent, spottee_pos : Vector3, visible_level : int) -> float:
	var dist = clampf(remap(spotter.position.distance_to(spottee_pos), 0.0, spotter.view_dist, 0.0, 1.0), 0.0, 1.0)
	var exponent = ((1.5 * dist)/(log(visible_level)/log(10)))
	var inv_eye = 1.0/spotter.eye_strength
	return maxf(1.0/(inv_eye**exponent), 0.01)

func try_see_agent(spotter : Agent, spottee : Agent):
	if spottee in spotter.detected:
		return
	var sight_chance = calculate_sight_chance(spotter, spottee.position, spottee.visible_level)
	print(sight_chance)
	if sight_chance > 0.7: # seent it
		spottee.visible = true
		create_popup(GameRefs.POPUP.spotted, spottee.position, true)
		spotter.detected_agents.append(spottee)
	elif sight_chance > 1.0/3.0: # almost seent it
		if spotter.player_id == spottee.player_id and not spottee.in_incapacitated_state(): # or we could just know them already
			return
		spotter.detected_agents.append(spottee)
		var p_offset = -0.1/sight_chance
		var x_off = randf_range(-p_offset, p_offset)
		var z_off = randf_range(-p_offset, p_offset)
		create_popup(GameRefs.POPUP.sight_unknown, spottee.position + Vector3(x_off, 0, z_off))


func try_see_element(spotter : Agent, element : Node3D):
	var sight_chance = calculate_sight_chance(spotter, element.position, 100)
	if sight_chance > 0.7:
		element.visible = true
		if element is GamePopup:
			element.disappear()


func determine_sounds():
	for agent in ($Agents.get_children() as Array[Agent]):
		if agent.in_incapacitated_state():
			continue # incapped agents are deaf
		for detected in agent._ears.get_overlapping_areas():
			var audio_event : GameAudioEvent = detected.get_parent()
			if agent.player_id == audio_event.player_id:
				continue # skip same team sources
			var hear_chance = audio_event.radius * agent.ear_strength * clampf(remap(agent.position.distance_to(detected.position), 0.0, agent.hearing_dist, 0.0, 1.0), 0.0, 1.0)
			if hear_chance > 0.5:
				create_popup(GameRefs.POPUP.sound_unknown, detected.position)
				audio_event.play_sound()
		match agent.state:
			Agent.States.WALK when agent.game_steps_since_execute % 40 == 0:
				create_sound_effect(agent.position, agent.player_id, 13, 0.25, 2.0, "ag_step_quiet")
			Agent.States.RUN when agent.game_steps_since_execute % 20 == 0:
				create_sound_effect(agent.position, agent.player_id, 13, 1.5, 2.75, "ag_step_loud")
			Agent.States.CROUCH_WALK when agent.game_steps_since_execute % 50 == 0:
				create_sound_effect(agent.position, agent.player_id, 13, 0.25, 2.0, "ag_step_quiet")
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
	match game_phase:
		GamePhases.SELECTION:
			for selector in $HUDSelectors.get_children() as Array[AgentSelector]:
				selector.position = (
			$World/Camera3D as Camera3D).unproject_position(
					selector.referenced_agent.position)
				(selector.get_child(0) as CollisionShape2D).shape.size = Vector2(32, 32) * GameCamera.MAX_FOV/_camera.fov
			if multiplayer.is_server() and server_ready_bool and client_ready_bool:
				_update_game_phase.rpc(GamePhases.EXECUTION)
		GamePhases.EXECUTION:
			determine_cqc_events()
			determine_weapon_events()
			for agent in ($Agents.get_children() as Array[Agent]):
				agent._game_step(delta)
			current_game_step += 1
			determine_sights()
			determine_sounds()
			determine_indicator_removals()
			if multiplayer.is_server():
				for agent in ($Agents.get_children() as Array[Agent]):
					if agent.action_done == Agent.ActionDoneness.NOT_DONE:
						return
				_update_game_phase.rpc(GamePhases.SELECTION)


func server_populate_variables(): #TODO
	# server's agents
	var data = {
		player_id = 1,
		agent_stats = Lobby.players[1].agents[GameSettings.selected_agents[0]],
		pos_x = game_map.agent_spawn_server_1.position.x,
		pos_y = game_map.agent_spawn_server_1.position.y,
		pos_z = game_map.agent_spawn_server_1.position.z,
		rot_y = game_map.agent_spawn_server_1.rotation.y,
	}
	ag_spawner.spawn(data)
	if len(GameSettings.selected_agents) > 1:
		data.agent_stats = Lobby.players[1].agents[GameSettings.selected_agents[1]]
		data.pos_x = game_map.agent_spawn_server_2.position.x
		data.pos_y = game_map.agent_spawn_server_2.position.y
		data.pos_z = game_map.agent_spawn_server_2.position.z
		data.rot_y = game_map.agent_spawn_server_2.rotation.y
		ag_spawner.spawn(data)
	if len(GameSettings.selected_agents) > 2:
		data.agent_stats = Lobby.players[1].agents[GameSettings.selected_agents[2]]
		data.pos_x = game_map.agent_spawn_server_3.position.x
		data.pos_y = game_map.agent_spawn_server_3.position.y
		data.pos_z = game_map.agent_spawn_server_3.position.z
		data.rot_y = game_map.agent_spawn_server_3.rotation.y
		ag_spawner.spawn(data)
	if len(GameSettings.selected_agents) > 3:
		data.agent_stats = Lobby.players[1].agents[GameSettings.selected_agents[3]]
		data.pos_x = game_map.agent_spawn_server_4.position.x
		data.pos_y = game_map.agent_spawn_server_4.position.y
		data.pos_z = game_map.agent_spawn_server_4.position.z
		data.rot_y = game_map.agent_spawn_server_4.rotation.y
		ag_spawner.spawn(data)
	# client's agents
	data.player_id = GameSettings.other_player_id
	data.agent_stats = Lobby.players[data.player_id].agents[GameSettings.client_selected_agents[0]]
	data.pos_x = game_map.agent_spawn_client_1.position.x
	data.pos_y = game_map.agent_spawn_client_1.position.y
	data.pos_z = game_map.agent_spawn_client_1.position.z
	data.rot_y = game_map.agent_spawn_client_1.rotation.y
	ag_spawner.spawn(data)
	if len(GameSettings.client_selected_agents) > 1:
		data.agent_stats = Lobby.players[data.player_id].agents[GameSettings.client_selected_agents[1]]
		data.pos_x = game_map.agent_spawn_client_2.position.x
		data.pos_y = game_map.agent_spawn_client_2.position.y
		data.pos_z = game_map.agent_spawn_client_2.position.z
		data.rot_y = game_map.agent_spawn_client_2.rotation.y
		ag_spawner.spawn(data)
	if len(GameSettings.client_selected_agents) > 2:
		data.agent_stats = Lobby.players[data.player_id].agents[GameSettings.client_selected_agents[2]]
		data.pos_x = game_map.agent_spawn_client_3.position.x
		data.pos_y = game_map.agent_spawn_client_3.position.y
		data.pos_z = game_map.agent_spawn_client_3.position.z
		data.rot_y = game_map.agent_spawn_client_3.rotation.y
		ag_spawner.spawn(data)
	if len(GameSettings.client_selected_agents) > 3:
		data.agent_stats = Lobby.players[data.player_id].agents[GameSettings.client_selected_agents[3]]
		data.pos_x = game_map.agent_spawn_client_4.position.x
		data.pos_y = game_map.agent_spawn_client_4.position.y
		data.pos_z = game_map.agent_spawn_client_4.position.z
		data.rot_y = game_map.agent_spawn_client_4.rotation.y
		ag_spawner.spawn(data)


#@rpc("authority", "call_local", "reliable")
#func create_all_raycasts():
	#for agent_block in server_agents.keys():
		#var agent = server_agents[agent_block]["agent_node"]
		#for cli_agent_block in client_agents.keys():
			#var cli_agent = client_agents[cli_agent_block]["agent_node"]
			#var new_tracking_ray = tracking_raycast3d_scene.instantiate()
			#new_tracking_ray.source = agent
			#new_tracking_ray.sink = cli_agent
			#new_tracking_ray.name = agent.name + "|" + cli_agent.name
			#$RayCasts.add_child(new_tracking_ray)
			#print("created ray ", new_tracking_ray)


func append_action_timeline(agent : Agent):
	if not action_timeline.has(current_game_step):
		action_timeline[current_game_step] = {}
	action_timeline[current_game_step][agent.name] = agent.queued_action


@rpc("call_local")
func ping():
	print("{0}: pong!".format([multiplayer.multiplayer_peer.get_unique_id()]))

#@rpc("authority", "call_local", "reliable")
func create_agent(data) -> Agent: #TODO
	var new_agent : Agent = agent_scene.instantiate()
	new_agent.name = str(data.player_id) + "_" + str(data.agent_stats.name)
	new_agent.agent_died.connect(_agent_died)

	new_agent.position = Vector3(data.pos_x, data.pos_y, data.pos_z)
	new_agent.rotation.y = data.rot_y
	new_agent.set_multiplayer_authority(data.player_id)
	new_agent.player_id = data.player_id
	new_agent.health = data.agent_stats.health
	new_agent.stun_health = data.agent_stats.health / 2
	new_agent.view_dist = data.agent_stats.view_dist
	new_agent.view_across = data.agent_stats.view_across
	new_agent.eye_strength = data.agent_stats.eye_strength
	new_agent.hearing_dist = data.agent_stats.hearing_dist
	new_agent.ear_strength = data.agent_stats.ear_strength
	new_agent.held_items = data.agent_stats.held_items
	new_agent.held_weapons.append(GameWeapon.new("fist", new_agent.name + "_fist"))
	for weapon in data.agent_stats.held_weapons:
		new_agent.held_weapons.append(GameWeapon.new(weapon, new_agent.name + "_" + weapon))
	new_agent.visible = false
	if multiplayer.multiplayer_peer.get_unique_id() == data.player_id:
		new_agent.visible = true
		var new_small_hud = hud_agent_small_scene.instantiate()
		_quick_views.add_child(new_small_hud)
		new_small_hud._health_bar.max_value = data.agent_stats.health
		new_small_hud._stun_health_bar.max_value = data.agent_stats.health / 2
		new_small_hud.ref_ag = new_agent

	return new_agent


func create_agent_selector(agent : Agent):
	var new_selector = agent_selector_scene.instantiate()
	new_selector.referenced_agent = agent
	new_selector.agent_selected.connect(_hud_agent_details_actions)
	$HUDSelectors.add_child(new_selector)


func _agent_lost_agent(unspotter : Agent, unspottee : Agent):
	if not unspotter.is_multiplayer_authority():
		return
	if unspotter.player_id != unspottee.player_id:
		pass


func _agent_lost_element(element : Node3D):
	pass


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
		grabber._anim_state.travel("B_Stand_Attack_Slam")
		grabbee.grabbing_agent = grabber
		grabbee.take_damage(3, true)
		grabbee.stun_time = 30 if grabbee.stun_health > 0 else 300
		grabbee._anim_state.travel("B_Hurt_Slammed")
		grabbee.state = Agent.States.GRABBED
		grabbee.queued_action.clear()
		pass

func slide_end_pos(start_pos : Vector3, end_pos : Vector3, change : float):
	return end_pos + start_pos.direction_to(end_pos).rotated(Vector3.DOWN, PI/2) * change

func determine_weapon_events():
	var attackers = {}

	for agent in ($Agents.get_children() as Array[Agent]):
		if agent.state != Agent.States.FIRE_GUN:
			continue
		agent.held_weapons[agent.selected_weapon].loaded_ammo -= 1
		match agent.held_weapons[agent.selected_weapon].wep_name:
			"pistol":
				attackers[agent] = [return_attacked(agent, agent.queued_action[1])]
				create_sound_effect(agent.position, agent.player_id, 10, 0.25, 0.5, "pistol")
			"rifle":
				attackers[agent] = [return_attacked(agent, slide_end_pos(agent._body.global_position, agent.queued_action[1], 0.2)),return_attacked(agent, slide_end_pos(agent._body.global_position, agent.queued_action[1], -0.2)),]
				create_sound_effect(agent.position, agent.player_id, 10, 0.5, 1.5, "rifle")
			"shotgun":
				attackers[agent] = [
	return_attacked(agent, slide_end_pos(agent._body.global_position, agent.queued_action[1], 1.0)), return_attacked(agent, agent.queued_action[1]), return_attacked(agent, slide_end_pos(agent._body.global_position, agent.queued_action[1], -1.0)),]
				create_sound_effect(agent.position, agent.player_id, 15, 2.25, 3.5, "shotgun")


	for attacker in (attackers.keys() as Array[Agent]):
		attacker.state = Agent.States.USING_WEAPON
		for hit in attackers[attacker]:
			#create_popup(GameRefs.POPUP.spotted, hit[1], true)
			if hit[0] == null: # hit a wall, make a sound event on the wall
				create_sound_effect(hit[1], attacker.player_id, 4, 0.5, 2, "projectile_bounce")
			else:
				if not (hit[0] as Area3D).get_parent() is Agent: # still hit a wall
					create_sound_effect(hit[1], attacker.player_id, 4, 0.5, 2, "projectile_bounce")
				else: # actually hit an agent
					var attacked : Agent = (hit[0] as Area3D).get_parent()
					if attacker.player_id == attacked.player_id:
						continue # same team can block bullets but won't take damage
					if attacked.stun_time > 0:
						continue # skip already attacked agents
					if attacked.in_prone_state():
						continue # skip prone agents
					attacked.take_damage(GameRefs.get_weapon_attribute(attacker, attacker.selected_weapon, "damage"))
					create_sound_effect(attacked.position, attacked.player_id, 5, 0.75, 2.5, "ag_hurt")
					attacked.stun_time = 60 if attacked.health > 0 else 300
					attacked.select_hurt_animation()
					attacked.state = Agent.States.HURT
					attacked.queued_action.clear()


func _agent_died(deceased : Agent):
	print(deceased.name, " has died, big f")
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
	# need to remove indicator if created
	if $ClientsideIndicators.get_node_or_null(String(ref_ag.name)):
		$ClientsideIndicators.get_node(String(ref_ag.name))._neutral()
		$ClientsideIndicators.get_node(String(ref_ag.name)).name += "_neutralling"
	set_agent_action.rpc(ref_ag.name, decision_array)
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
				ref_ag.name, GameRefs.get_weapon_attribute(ref_ag, decision_array[1], "name")])
		Agent.GameActions.PICK_UP_WEAPON:
			final_text_string = "{0}: Pick up {1}".format([
				ref_ag.name,
				GameRefs.WEP[decision_array[1]].name])
		Agent.GameActions.DROP_WEAPON:
			final_text_string = "{0}: Drop {1}".format([
				ref_ag.name, GameRefs.get_weapon_attribute(ref_ag, decision_array[1], "name")])
		Agent.GameActions.RELOAD_WEAPON:
			final_text_string = "{0}: Reload {1}".format([
				ref_ag.name, GameRefs.get_weapon_attribute(ref_ag, decision_array[1], "name")])
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
	if ref_ag.is_multiplayer_authority():
		ref_ag.action_text = final_text_string
	update_text()


func _on_radial_menu_movement_decision_made(decision_array: Array) -> void:
	var ref_ag : Agent = _radial_menu.referenced_agent
	_radial_menu.referenced_agent = null
	# need to remove indicator if created
	if $ClientsideIndicators.get_node_or_null(String(ref_ag.name)):
		$ClientsideIndicators.get_node(String(ref_ag.name))._neutral()
		$ClientsideIndicators.get_node(String(ref_ag.name)).name += "_neutralling"
	set_agent_action.rpc(ref_ag.name, decision_array)
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
	if ref_ag.is_multiplayer_authority():
		ref_ag.action_text = final_text_string
	update_text()


func _on_radial_menu_aiming_decision_made(decision_array: Array) -> void:
	var ref_ag : Agent = _radial_menu.referenced_agent
	_radial_menu.referenced_agent = null
	# need to remove indicator if created
	if $ClientsideIndicators.get_node_or_null(String(ref_ag.name)):
		$ClientsideIndicators.get_node(String(ref_ag.name))._neutral()
		$ClientsideIndicators.get_node(String(ref_ag.name)).name += "_neutralling"
	set_agent_action.rpc(ref_ag.name, decision_array)
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
	match decision_array[0]:
		Agent.GameActions.LOOK_AROUND:
			final_text_string = "{0}: Look at Position".format([ref_ag.name])
		Agent.GameActions.USE_WEAPON:
			final_text_string = "{0}: Use {1} at Position".format(
				[ref_ag.name, GameRefs.get_weapon_attribute(ref_ag, ref_ag.selected_weapon, "name")])
	if ref_ag.is_multiplayer_authority():
		ref_ag.action_text = final_text_string
	update_text()


@rpc("authority", "call_local", "reliable")
func _update_game_phase(new_phase: GamePhases, check_incap := true):
	game_phase = new_phase
	match new_phase:
		GamePhases.SELECTION:
			_round_ended.play()
			_phase_label.text = "SELECT ACTIONS"
			_execute_button.disabled = false
			_execute_button.text = "EXECUTE INSTRUCTIONS"
			for ag in ($Agents.get_children() as Array[Agent]):
				ag.action_done = Agent.ActionDoneness.NOT_DONE
				if multiplayer.is_server():
					set_agent_action.rpc(ag.name, [])
				if ag.is_multiplayer_authority() and not ag.in_incapacitated_state():
					create_agent_selector(ag)
					ag.flash_outline(Color.ORCHID)
			show_hud()
			#if event occurred: TODO
				#_round_update.play()
			if $HUDSelectors.get_child_count() == 0 and check_incap:
				_on_execute_pressed() # run the execute function since the player can't do anything
		GamePhases.EXECUTION:
			for selector in $HUDSelectors.get_children(): # remove previous selectors
				selector.queue_free()
			for agent in ($Agents.get_children() as Array[Agent]):
				agent.action_text = ""
			update_text()
			_phase_label.text = "EXECUTING ACTIONS..."
			server_ready_bool = false
			client_ready_bool = false
			# populate agents with actions, as well as action_timeline
			for agent in ($Agents.get_children() as Array[Agent]):
				agent.agent_is_done.rpc(Agent.ActionDoneness.NOT_DONE)
				if multiplayer.is_server():
					append_action_timeline(agent)
				agent.perform_action()
			await get_tree().create_timer(0.10).timeout


@rpc("any_peer", "call_local", "reliable")
func player_is_ready(id):
	if id == 1:
		server_ready_bool = true
	else:
		client_ready_bool = true


@rpc("any_peer", "call_local", "reliable")
func set_agent_action(agent_name : String, action : Array):
	$Agents.get_node(agent_name).queued_action = action

func _on_execute_pressed() -> void:
	_actions_submitted.play()
	_execute_button.disabled = true
	_execute_button.text = "WAITING FOR OPPONENT"
	_radial_menu.button_collapse_animation()
	hide_hud()
	player_is_ready.rpc(multiplayer.get_unique_id())


func _on_cold_boot_timer_timeout() -> void:
	_update_game_phase(GamePhases.SELECTION, false)
