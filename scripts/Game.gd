class_name Game
extends Node3D


var aiming_icon_scene = preload("res://scenes/game_aiming_indicator.tscn")
var tracking_raycast3d_scene = preload("res://scenes/tracking_raycast3d.tscn")
var movement_icon_scene = preload("res://scenes/game_movement_indicator.tscn")
var popup_scene = preload("res://scenes/game_popup.tscn")

enum SelectionSteps {
	BASE,
	MOVEMENT,
	AIMING,
}
var selection_step : SelectionSteps = SelectionSteps.BASE

@onready var camera : GameCamera = $World/Camera3D

@onready var ui = $UI
@onready var server = $MultiplayerHandler

func start_game(): # Called only on the server.
	await ($MultiplayerLoadTimer as Timer).timeout # wait for client to load in
	ping.rpc()
	server.init_game()
	($ColdBootTimer as Timer).start()


@rpc("authority", "call_remote", "reliable")
func force_camera(new_pos, new_fov = -1.0):
	if new_pos is Vector2:
		camera.final_position = new_pos * Vector2(get_viewport().size/camera.sensitivity)
	elif new_pos is Vector3:
		camera.final_position = Vector2(new_pos.x, new_pos.z) * Vector2(get_viewport().size/camera.sensitivity)
	if new_fov != -1.0:
		camera.fov_target = new_fov


func create_popup(texture : Texture2D, location : Vector3, fleeting : bool = false) -> void:
	location.y += 3.0
	var new_popup : GamePopup = popup_scene.instantiate()
	new_popup.texture = texture
	new_popup.position = location
	$Popups.add_child(new_popup)
	if fleeting:
		new_popup.disappear()


func agent_children() -> Array[Agent]:
	return $Agents.get_children() as Array[Agent]


func determine_sights():
	for agent in agent_children():
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
		if server.current_game_step - spottee.step_seen < server.REMEMBER_TILL and spottee.step_seen > 0:
			server.set_agent_step_seen.rpc(spottee.name, server.current_game_step)
			return
		server.set_agent_step_seen.rpc(spottee.name, server.current_game_step)
		if spotter.player_id == 1:
			server.set_agent_server_visibility.rpc(spottee.name, true)
		else:
			server.set_agent_client_visibility.rpc(spottee.name, true)
		create_popup(GameRefs.POPUP.spotted, spottee.position, true)
		if spotter.player_id != spottee.player_id:
			spotter.sounds.spotted_agent.play()
	elif sight_chance > 1.0/3.0: # almost seent it
		if spottee.noticed > 0:
			return
		server.set_agent_notice.rpc(spottee.name, 10)
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
	for agent in agent_children():
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
					server.create_sound_effect.rpc(agent.position, agent.player_id, 13, 0.25, 2.0, "ag_step_quiet")
				Agent.States.RUN when agent.game_steps_since_execute % 20 == 0:
					server.create_sound_effect.rpc(agent.position, agent.player_id, 13, 1.5, 2.75, "ag_step_loud")
				Agent.States.CROUCH_WALK when agent.game_steps_since_execute % 50 == 0:
					server.create_sound_effect.rpc(agent.position, agent.player_id, 13, 0.25, 2.0, "ag_step_quiet")
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


func verify_game_completeness() -> bool:
	for selector in $HUDSelectors.get_children() as Array[AgentSelector]:
		if selector.referenced_agent == null: # the only case where the agent is null is the one where the node was destroyed by the server disconnecting
			for selector_to_free in $HUDSelectors.get_children() as Array[AgentSelector]:
				selector_to_free.queue_free()
			return true
	return false


func _physics_process(delta: float) -> void:
	match server.game_phase:
		server.GamePhases.SELECTION:
			if verify_game_completeness():
				server._update_game_phase(server.GamePhases.COMPLETION)
			else:
				for selector in $HUDSelectors.get_children() as Array[AgentSelector]:
					selector.position = camera.unproject_position(
						selector.referenced_agent.position)
					selector.collide.shape.size = Vector2(32, 32) * GameCamera.MAX_FOV/camera.fov
		server.GamePhases.EXECUTION:
			determine_cqc_events()
			determine_weapon_events()
			for agent in agent_children():
				agent._game_step(delta)
				agent.in_smoke = false
				#agent._debug_label.text = str(agent.target_visible_level) + "\n" + str(agent.noticed) + "\n" + str(current_game_step - agent.step_seen) + " : " + str(agent.step_seen)
				if server.current_game_step - agent.step_seen == server.REMEMBER_TILL and agent.visible:
					if agent.player_id == 1:
						server.set_agent_client_visibility.rpc(agent.name, false)
						if not multiplayer.is_server():
							create_popup(GameRefs.POPUP.sight_unknown, agent.position)
					else:
						server.set_agent_server_visibility.rpc(agent.name, false)
						if multiplayer.is_server():
							create_popup(GameRefs.POPUP.sight_unknown, agent.position)
				if len(agent.mark_for_drop) > 0 and multiplayer.is_server():
					var new_drop = {
						pos_x = agent.mark_for_drop.position.x,
						pos_y = agent.mark_for_drop.position.y,
						pos_z = agent.mark_for_drop.position.z,
						server_knows = agent.player_id == 1 or $Weapons.get_node(str(agent.mark_for_drop.wep_node)).is_map_element(),
						client_knows = agent.player_id != 1 or $Weapons.get_node(str(agent.mark_for_drop.wep_node)).is_map_element(),
						wep_name = str(agent.mark_for_drop.wep_node),
					}
					server.pickup_spawner.spawn(new_drop)
					#agent.held_weapons.erase(agent.mark_for_drop.wep_node)
					if multiplayer.is_server():
						server.remove_weapon_from_agent.rpc(agent.name, agent.mark_for_drop.wep_node)
					agent.mark_for_drop.clear()
				if multiplayer.is_server() and agent.try_grab_pickup and len(agent.queued_action) > 1:
					if $Pickups.get_node_or_null(str(agent.queued_action[1])) != null:
						$Pickups.get_node(str(agent.queued_action[1])).queue_free()
					agent.try_grab_pickup = false
				if multiplayer.is_server() and agent.state == Agent.States.DEAD and len(agent.held_weapons) > 1:
					var new_drop = {
						pos_x = agent.global_position.x + (randf() - 0.5),
						pos_y = agent.global_position.y,
						pos_z = agent.global_position.z + (randf() - 0.5),
						server_knows = agent.player_id == 1 or $Weapons.get_node(str(agent.held_weapons[1])).is_map_element(),
						client_knows = agent.player_id != 1 or $Weapons.get_node(str(agent.held_weapons[1])).is_map_element(),
						wep_name = str(agent.held_weapons[1]),
					}
					server.pickup_spawner.spawn(new_drop)
					server.remove_weapon_from_agent.rpc(agent.name, new_drop.wep_name)
				if multiplayer.is_server() and agent.mark_for_grenade_throw:
					var try_name = agent.held_weapons[agent.selected_weapon]
					while try_name in server.grenades_in_existence:
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
					server.grenade_spawner.spawn(grenade_data)
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
								if multiplayer.is_server():
									server.damage_agent.rpc(attacked.name, 2, false)
									server.create_sound_effect.rpc(attacked.position, attacked.player_id, 5, 0.75, 2.5, "ag_hurt")
							if multiplayer.is_server():
								server.create_sound_effect.rpc(grenade.global_position, grenade.player_id, 10, 0.1, 5.0, "grenade_frag")
						"grenade_smoke":
							server.smoke_spawner.spawn({
								pos_x = grenade.position.x,
								pos_y = grenade.position.y,
								pos_z = grenade.position.z,
								wep_name = grenade.name,
							})
							if multiplayer.is_server():
								server.create_sound_effect.rpc(grenade.global_position, grenade.player_id, 10, 0.1, 5.0, "grenade_smoke")
						"grenade_noise":
							if multiplayer.is_server():
								server.create_sound_effect.rpc(grenade.global_position, grenade.player_id, 10, 0.1, 10.0, "grenade_frag")
					if multiplayer.is_server():
						server.grenades_in_existence.erase(grenade.name)
						grenade.queue_free()
			for smoke in ($Smokes.get_children() as Array[Smoke]):
				smoke._tick()
				for caught in smoke.col_area.get_overlapping_areas():
					caught.get_parent().in_smoke = true
				if multiplayer.is_server() and smoke.lifetime > 205:
					smoke.queue_free()
			for pickup in ($Pickups.get_children() as Array[WeaponPickup]):
				pickup._animate(delta)
			#if multiplayer.is_server():
			server.current_game_step += 1
			determine_sights()
			determine_sounds()
			determine_indicator_removals()
			if multiplayer.is_server():
				for agent in agent_children():
					if agent.action_done == Agent.ActionDoneness.NOT_DONE:
						return
				server.update_game_phase.rpc(server.GamePhases.SELECTION)
		server.GamePhases.COMPLETION:
			for ag in agent_children():
				ag.visible = true
				ag.queued_action.clear()
				if ag.in_standing_state():
					ag.state = Agent.States.STAND
				elif ag.in_crouching_state():
					ag.state = Agent.States.CROUCH
				elif ag.in_prone_state():
					ag.state = Agent.States.PRONE
				ag._game_step(delta, true)


@rpc("call_local")
func ping():
	print("{0}: pong!".format([multiplayer.multiplayer_peer.get_unique_id()]))


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
	for agent in agent_children():
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
			server.damage_agent.rpc(grabbee.name, 3, true)
		grabbee.step_seen = server.current_game_step

func slide_end_pos(start_pos : Vector3, end_pos : Vector3, change : float):
	return end_pos + start_pos.direction_to(end_pos).rotated(Vector3.DOWN, PI/2) * change

func determine_weapon_events():
	var attackers = {}
	for agent in agent_children():
		if agent.state != Agent.States.FIRE_GUN:
			continue
		GameRefs.get_weapon_node(agent.held_weapons[agent.selected_weapon]).loaded_ammo -= 1
		match GameRefs.get_weapon_node(agent.held_weapons[agent.selected_weapon]).wep_id:
			"pistol":
				attackers[agent] = [return_attacked(agent, agent.queued_action[1])]
				if multiplayer.is_server():
					server.create_sound_effect.rpc(agent.position, agent.player_id, 10, 0.25, 0.5, "pistol")
			"rifle":
				attackers[agent] = [return_attacked(agent, slide_end_pos(agent._body.global_position, agent.queued_action[1], 0.2)),return_attacked(agent, slide_end_pos(agent._body.global_position, agent.queued_action[1], -0.2)),]
				if multiplayer.is_server():
					server.create_sound_effect.rpc(agent.position, agent.player_id, 10, 0.5, 1.5, "rifle")
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
					server.create_sound_effect.rpc(agent.position, agent.player_id, 15, 2.25, 3.5, "shotgun")
	for attacker in (attackers.keys() as Array[Agent]):
		attacker.state = Agent.States.USING_WEAPON
		for hit in attackers[attacker]:
			if hit[0] == null: # hit a wall, make a sound event on the wall
				if multiplayer.is_server():
					server.create_sound_effect.rpc(hit[1], attacker.player_id, 4, 0.5, 2, "projectile_bounce")
			else:
				if not (hit[0] as Area3D).get_parent() is Agent: # still hit a wall
					if multiplayer.is_server():
						server.create_sound_effect.rpc(hit[1], attacker.player_id, 4, 0.5, 2, "projectile_bounce")
				else: # actually hit an agent
					var attacked : Agent = (hit[0] as Area3D).get_parent()
					if attacker.player_id == attacked.player_id:
						continue # same team can block bullets but won't take damage
					if attacked.stun_time > 0:
						continue # skip already attacked agents
					if attacked.in_prone_state() or attacked.state == Agent.States.DEAD:
						continue # skip prone agents
					if multiplayer.is_server():
						server.damage_agent.rpc(attacked.name, GameRefs.get_held_weapon_attribute(attacker, attacker.selected_weapon, "damage"), false)
						server.create_sound_effect.rpc(attacked.position, attacked.player_id, 5, 0.75, 2.5, "ag_hurt")


func _on_radial_menu_decision_made(decision_array: Array) -> void:
	var ref_ag : Agent = ui.pop_radial_menu_agent()
	if $ClientsideIndicators.get_node_or_null(String(ref_ag.name)): # remove prev indicator
		$ClientsideIndicators.get_node(String(ref_ag.name))._neutral()
		$ClientsideIndicators.get_node(String(ref_ag.name)).name += "_neutralling"
	server.set_agent_action.rpc(ref_ag.name, decision_array)
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
	if ref_ag.is_multiplayer_authority():
		ref_ag.action_text = final_text_string
	ui.update_text()
	ui.execute_button.visible = true
	ui.execute_button.disabled = false


func _on_radial_menu_movement_decision_made(decision_array: Array) -> void:
	var ref_ag : Agent = ui.pop_radial_menu_agent()
	if $ClientsideIndicators.get_node_or_null(String(ref_ag.name)):
		$ClientsideIndicators.get_node(String(ref_ag.name))._neutral()
		$ClientsideIndicators.get_node(String(ref_ag.name)).name += "_neutralling"
	server.set_agent_action.rpc(ref_ag.name, decision_array)
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
	if ref_ag.is_multiplayer_authority():
		ref_ag.action_text = final_text_string
	ui.update_text()
	ui.execute_button.visible = true
	ui.execute_button.disabled = false


func _on_radial_menu_aiming_decision_made(decision_array: Array) -> void:
	var ref_ag : Agent = ui.pop_radial_menu_agent()
	if $ClientsideIndicators.get_node_or_null(String(ref_ag.name)):
		$ClientsideIndicators.get_node(String(ref_ag.name))._neutral()
		$ClientsideIndicators.get_node(String(ref_ag.name)).name += "_neutralling"
	server.set_agent_action.rpc(ref_ag.name, decision_array)
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
	if ref_ag.is_multiplayer_authority():
		ref_ag.action_text = final_text_string
	ui.update_text()
	ui.execute_button.visible = true
	ui.execute_button.disabled = false


func save_replay():
	server.action_timeline[server.current_game_step] = "END"
	var end_time = str(int(Time.get_unix_time_from_system()))
	if DirAccess.open("user://replays") == null:
		DirAccess.make_dir_absolute("user://replays")
	var new_replay = FileAccess.open("user://replays/" + server.start_time + "_" + end_time + ".mstr", FileAccess.WRITE)
	new_replay.store_string(JSON.stringify(server.action_timeline))


func check_agents_for_weapon(item_name : String) -> bool:
	for ag in agent_children():
		if not ag.is_multiplayer_authority():
			continue
		if ag.state == Agent.States.DEAD:
			continue
		if item_name in ag.held_weapons:
			return true
	return false


func check_weapon_holder_exfil(item_name : String) -> bool:
	for ag in agent_children():
		if not ag.is_multiplayer_authority():
			continue
		if ag.state == Agent.States.DEAD:
			continue
		if ag.state != Agent.States.EXFILTRATED:
			continue
		if item_name in ag.held_weapons:
			return true
	return false


func check_full_team_exfil_or_dead():
	var count = 0
	for ag in agent_children():
		if not ag.is_multiplayer_authority():
			continue
		count += 1
		if ag.state in [Agent.States.EXFILTRATED, Agent.States.DEAD]:
			count -= 1
	return count == 0


func player_quits(_peer_id):
	if server.game_phase == server.GamePhases.COMPLETION or server.server_progress > server.ProgressParts.NO_ADVANTAGE or server.client_progress > server.ProgressParts.NO_ADVANTAGE:
		return
	server.create_toast_update(GameRefs.TXT.forfeit, GameRefs.TXT.forfeit, false)
	$FadeOut/ColorRect/AnimatedSprite2D.play("victory")
	ui.animate_fade(true)
	server.update_game_phase(server.GamePhases.COMPLETION)


func _on_pickup_spawner_despawned(node: Node) -> void:
	node.queue_free()


func _on_yes_forfeit_pressed() -> void:
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
	save_replay()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
