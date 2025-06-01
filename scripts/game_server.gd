extends Node

@export var game : Game

func _ready() -> void:
	if not multiplayer.is_server():
		queue_free()


func _physics_process(delta: float) -> void:
	if game.game_phase == game.GamePhases.EXECUTION:
		determine_cqc_events()
		determine_weapon_events()
		for agent in ($"../Agents".get_children() as Array[Agent]):
			agent._game_step(delta)
			agent.in_smoke = false
			if game.current_game_step - agent.step_seen == game.REMEMBER_TILL and agent.visible:
				if agent.player_id == 1:
					agent.client_knows = false
					game.create_popup.rpc_id(GameSettings.other_player_id, "sight_unknown", agent.position)
				else:
					agent.server_knows = false
					game.create_popup("sight_unknown", agent.position)
			if len(agent.mark_for_drop) > 0:
				game.pickup_spawner.spawn({
					pos_x = agent.mark_for_drop.position.x,
					pos_y = agent.mark_for_drop.position.y,
					pos_z = agent.mark_for_drop.position.z,
					server_knows = agent.player_id == 1 or $"../Weapons".get_node(str(agent.mark_for_drop.wep_node)).is_map_element(),
					client_knows = agent.player_id != 1 or $"../Weapons".get_node(str(agent.mark_for_drop.wep_node)).is_map_element(),
					wep_name = str(agent.mark_for_drop.wep_node),
				})
				agent.held_weapons.erase(agent.mark_for_drop.wep_node)
				agent.mark_for_drop.clear()
			if agent.try_grab_pickup and len(agent.queued_action) > 1:
				if $"../Pickups".get_node_or_null(str(agent.queued_action[1])) != null:
					$"../Pickups".get_node(str(agent.queued_action[1])).queue_free()
				agent.try_grab_pickup = false
			if agent.state == Agent.States.DEAD and len(agent.held_weapons) > 1:
				game.pickup_spawner.spawn({
					pos_x = agent.global_position.x + (randf() - 0.5),
					pos_y = agent.global_position.y,
					pos_z = agent.global_position.z + (randf() - 0.5),
					server_knows = agent.player_id == 1 or $"../Weapons".get_node(str(agent.held_weapons[1])).is_map_element(),
					client_knows = agent.player_id != 1 or $"../Weapons".get_node(str(agent.held_weapons[1])).is_map_element(),
					wep_name = str(agent.held_weapons[1]),
				})
				agent.held_weapons.erase(str(agent.held_weapons[1]))
			if agent.mark_for_grenade_throw:
				var try_name = agent.held_weapons[agent.selected_weapon]
				while try_name in game.grenades_in_existence:
					try_name += "N"
				game.grenade_spawner.spawn({
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
				})
				agent.mark_for_grenade_throw = false
		for grenade in ($"../Grenades".get_children() as Array[Grenade]):
			grenade._tick()
			if grenade.explode:
				match grenade.wep_id:
					"grenade_frag":
						for exploded in grenade._explosion_hitbox.get_overlapping_areas():
							var attacked : Agent = exploded.get_parent()
							if attacked.in_prone_state():
								continue # prone agents dodge explosions for Reasons™
							attacked.take_damage(2, false)
							game.audio_spawner.spawn({
								player = attacked.player_id,
								agent = attacked.name,
								pos_x = attacked.position.x, pos_y = attacked.position.y, pos_z = attacked.position.z,
								max_rad = 2.5, lifetime = 5, sound_id = "ag_hurt",
							})
						game.audio_spawner.spawn({
							player = grenade.player_id,
							agent = grenade.name,
							pos_x = grenade.global_position.x, pos_y = grenade.global_position.y, pos_z = grenade.global_position.z,
							max_rad = 5.0, lifetime = 10, sound_id = "grenade_frag",
						})
					"grenade_smoke":
						game.smoke_spawner.spawn({
							pos_x = grenade.position.x,
							pos_y = grenade.position.y,
							pos_z = grenade.position.z,
							wep_name = grenade.name,
						})
						game.audio_spawner.spawn({
							player = grenade.player_id,
							agent = grenade.name,
							pos_x = grenade.global_position.x, pos_y = grenade.global_position.y, pos_z = grenade.global_position.z,
							max_rad = 5.0, lifetime = 10, sound_id = "grenade_smoke",
						})
					"grenade_noise":
						game.audio_spawner.spawn({
							player = grenade.player_id,
							agent = grenade.name,
							pos_x = grenade.global_position.x, pos_y = grenade.global_position.y, pos_z = grenade.global_position.z,
							max_rad = 10.0, lifetime = 10, sound_id = "grenade_frag",
						})
				game.grenades_in_existence.erase(grenade.name)
				grenade.queue_free()
		for smoke in ($"../Smokes".get_children() as Array[Smoke]):
			smoke._tick()
			for caught in smoke.col_area.get_overlapping_areas():
				caught.get_parent().in_smoke = true
			if smoke.lifetime > 205:
				smoke.queue_free()
		for pickup in ($"../Pickups".get_children() as Array[WeaponPickup]):
			pickup._animate(delta)
		game.current_game_step += 1
		determine_sights()
		determine_sounds()
		for agent in ($"../Agents".get_children() as Array[Agent]):
			if agent.action_done == Agent.ActionDoneness.NOT_DONE:
				return
		game._update_game_phase(game.GamePhases.COMPLETION)
	elif game.game_phase == game.GamePhases.COMPLETION:
		for ag in ($"../Agents".get_children() as Array[Agent]):
			ag.visible = true
			ag.queued_action.clear()
			if ag.in_standing_state():
				ag.state = Agent.States.STAND
			elif ag.in_crouching_state():
				ag.state = Agent.States.CROUCH
			elif ag.in_prone_state():
				ag.state = Agent.States.PRONE
			ag._game_step(delta, true)

func determine_cqc_events():
	var cqc_actors = {}
	for agent in ($"../Agents".get_children() as Array[Agent]):
		if agent.state != Agent.States.CQC_GRAB:
			continue
		cqc_actors[agent] = game.return_attacked(agent, agent.queued_action[1])[0]
	for grabber in (cqc_actors.keys() as Array[Agent]):
		grabber.state = Agent.States.USING_WEAPON
		if cqc_actors[grabber] == null:
			continue
		if not (cqc_actors[grabber] as Area3D).get_parent() is Agent:
			grabber.do_anim.rpc("B_Stand_Attack_Whiff")
			grabber.game_steps_since_execute = Agent.CQC_STEP_FAIL_START
			continue
		var grabbee : Agent = (cqc_actors[grabber] as Area3D).get_parent()
		if grabbee in cqc_actors and grabber.player_id == 1: #client wins tiebreakers
			grabber.do_anim.rpc("B_Stand_Attack_Whiff")
			grabber.game_steps_since_execute = Agent.CQC_STEP_FAIL_START
			continue
		if grabber.player_id == grabbee.player_id: # don't grab your friends
			grabber.do_anim.rpc("B_Stand_Attack_Whiff")
			grabber.game_steps_since_execute = Agent.CQC_STEP_FAIL_START
			continue
		if grabbee.in_incapacitated_state(): # don't grab people who're already on the ground
			grabber.do_anim.rpc("B_Stand_Attack_Whiff")
			grabber.game_steps_since_execute = Agent.CQC_STEP_FAIL_START
			continue
		if grabbee.selected_item > -1 and grabbee.held_items[grabbee.selected_item] == "box":
			grabber.do_anim.rpc("B_Stand_Attack_Whiff")
			grabber.game_steps_since_execute = Agent.CQC_STEP_FAIL_START  # don't grab boxes
			continue
		if grabbee.ungrabbable: # don't grab the ungrabbable
			grabber.do_anim.rpc("B_Stand_Attack_Whiff")
			grabber.game_steps_since_execute = Agent.CQC_STEP_FAIL_START
			continue
		grabber.do_anim.rpc("B_Stand_Attack_Slam")
		grabber.game_steps_since_execute = Agent.CQC_STEP_SUCCESS_START
		grabbee.grabbing_agent = grabber
		grabbee.take_damage(3, true)
		grabbee.step_seen = game.current_game_step

func determine_weapon_events():
	var attackers = {}
	for agent in ($"../Agents".get_children() as Array[Agent]):
		if agent.state != Agent.States.FIRE_GUN:
			continue
		GameRefs.get_weapon_node(agent.held_weapons[agent.selected_weapon]).loaded_ammo -= 1
		match GameRefs.get_weapon_node(agent.held_weapons[agent.selected_weapon]).wep_id:
			"pistol":
				attackers[agent] = [game.return_attacked(agent, agent.queued_action[1])]
				game.audio_spawner.spawn({
					player = agent.player_id,
					agent = agent.name,
					pos_x = agent.position.x, pos_y = agent.position.y, pos_z = agent.position.z,
					max_rad = 0.5, lifetime = 10, sound_id = "pistol",
				})
			"rifle":
				attackers[agent] = [game.return_attacked(agent, game.slide_end_pos(agent._body.global_position, agent.queued_action[1], 0.2)),game.return_attacked(agent, game.slide_end_pos(agent._body.global_position, agent.queued_action[1], -0.2)),]
				game.audio_spawner.spawn({
					player = agent.player_id,
					agent = agent.name,
					pos_x = agent.position.x, pos_y = agent.position.y, pos_z = agent.position.z,
					max_rad = 1.5, lifetime = 10, sound_id = "rifle",
				})
			"shotgun":
				attackers[agent] = [
					game.return_attacked(
						agent,
						game.slide_end_pos(agent._body.global_position, agent.queued_action[1], 1.0)
						),
					game.return_attacked(
						agent,
						agent.queued_action[1]
						),
					game.return_attacked(
						agent,
						game.slide_end_pos(agent._body.global_position, agent.queued_action[1], -1.0)
						),
					]

				game.audio_spawner.spawn({
					player = agent.player_id,
					agent = agent.name,
					pos_x = agent.position.x, pos_y = agent.position.y, pos_z = agent.position.z,
					max_rad = 3.5, lifetime = 15, sound_id = "shotgun",
				})
	for attacker in (attackers.keys() as Array[Agent]):
		attacker.state = Agent.States.USING_WEAPON
		for hit in attackers[attacker]:
			if hit[0] == null: # hit a wall, make a sound event on the wall
				game.audio_spawner.spawn({
					player = attacker.player_id,
					agent = attacker.name,
					pos_x = hit[1].position.x, pos_y = hit[1].position.y, pos_z = hit[1].position.z,
					max_rad = 2, lifetime = 4, sound_id = "projectile_bounce",
				})
			else:
				if not (hit[0] as Area3D).get_parent() is Agent: # still hit a wall
					game.audio_spawner.spawn({
						player = attacker.player_id,
						agent = attacker.name,
						pos_x = hit[1].position.x, pos_y = hit[1].position.y, pos_z = hit[1].position.z,
						max_rad = 2, lifetime = 4, sound_id = "projectile_bounce",
					})
				else: # actually hit an agent
					var attacked : Agent = (hit[0] as Area3D).get_parent()
					if attacker.player_id == attacked.player_id:
						continue # same team can block bullets but won't take damage
					if attacked.stun_time > 0:
						continue # skip already attacked agents
					if attacked.in_prone_state() or attacked.state == Agent.States.DEAD:
						continue # skip prone agents
					attacked.take_damage(GameRefs.get_held_weapon_attribute(attacker, attacker.selected_weapon, "damage"), false)
					game.audio_spawner.spawn({
						player = attacked.player_id,
						agent = attacked.name,
						pos_x = attacked.position.x, pos_y = attacked.position.y, pos_z = attacked.position.z,
						max_rad = 2.5, lifetime = 5, sound_id = "ag_hurt",
					})



func populate_variables():
	# server's agents
	var data = {
		player_id = 1,
		agent_stats = Lobby.players[1].agents[GameSettings.selected_agents[0]],
		pos_y = game.map.agent_spawn_server_1.position.y - 0.666,
		pos_z = game.map.agent_spawn_server_1.position.z,
		pos_x = game.map.agent_spawn_server_1.position.x,
		rot_y = game.map.agent_spawn_server_1.rotation.y,
	}
	game.ag_spawner.spawn(data)
	if len(GameSettings.selected_agents) > 1:
		data.agent_stats = Lobby.players[1].agents[GameSettings.selected_agents[1]]
		data.pos_x = game.map.agent_spawn_server_2.position.x
		data.pos_y = game.map.agent_spawn_server_2.position.y - 0.666
		data.pos_z = game.map.agent_spawn_server_2.position.z
		data.rot_y = game.map.agent_spawn_server_2.rotation.y
		game.ag_spawner.spawn(data)
	if len(GameSettings.selected_agents) > 2:
		data.agent_stats = Lobby.players[1].agents[GameSettings.selected_agents[2]]
		data.pos_x = game.map.agent_spawn_server_3.position.x
		data.pos_y = game.map.agent_spawn_server_3.position.y - 0.666
		data.pos_z = game.map.agent_spawn_server_3.position.z
		data.rot_y = game.map.agent_spawn_server_3.rotation.y
		game.ag_spawner.spawn(data)
	if len(GameSettings.selected_agents) > 3:
		data.agent_stats = Lobby.players[1].agents[GameSettings.selected_agents[3]]
		data.pos_x = game.map.agent_spawn_server_4.position.x
		data.pos_y = game.map.agent_spawn_server_4.position.y - 0.666
		data.pos_z = game.map.agent_spawn_server_4.position.z
		data.rot_y = game.map.agent_spawn_server_4.rotation.y
		game.ag_spawner.spawn(data)
	# client's agents
	data.player_id = GameSettings.other_player_id
	data.agent_stats = Lobby.players[data.player_id].agents[GameSettings.client_selected_agents[0]]
	data.pos_x = game.map.agent_spawn_client_1.position.x
	data.pos_y = game.map.agent_spawn_client_1.position.y - 0.666
	data.pos_z = game.map.agent_spawn_client_1.position.z
	data.rot_y = game.map.agent_spawn_client_1.rotation.y
	game.ag_spawner.spawn(data)
	if len(GameSettings.client_selected_agents) > 1:
		data.agent_stats = Lobby.players[data.player_id].agents[GameSettings.client_selected_agents[1]]
		data.pos_x = game.map.agent_spawn_client_2.position.x
		data.pos_y = game.map.agent_spawn_client_2.position.y - 0.666
		data.pos_z = game.map.agent_spawn_client_2.position.z
		data.rot_y = game.map.agent_spawn_client_2.rotation.y
		game.ag_spawner.spawn(data)
	if len(GameSettings.client_selected_agents) > 2:
		data.agent_stats = Lobby.players[data.player_id].agents[GameSettings.client_selected_agents[2]]
		data.pos_x = game.map.agent_spawn_client_3.position.x
		data.pos_y = game.map.agent_spawn_client_3.position.y - 0.666
		data.pos_z = game.map.agent_spawn_client_3.position.z
		data.rot_y = game.map.agent_spawn_client_3.rotation.y
		game.ag_spawner.spawn(data)
	if len(GameSettings.client_selected_agents) > 3:
		data.agent_stats = Lobby.players[data.player_id].agents[GameSettings.client_selected_agents[3]]
		data.pos_x = game.map.agent_spawn_client_4.position.x
		data.pos_y = game.map.agent_spawn_client_4.position.y - 0.666
		data.pos_z = game.map.agent_spawn_client_4.position.z
		data.rot_y = game.map.agent_spawn_client_4.rotation.y
		game.ag_spawner.spawn(data)


func _on_multiplayer_load_timer_timeout() -> void:
	game.ping.rpc()
	game.set_start_time.rpc(str(int(Time.get_unix_time_from_system())))
	populate_variables()
	game.force_camera.rpc_id(
		GameSettings.other_player_id,
		(game.map.agent_spawn_client_1.position + game.map.agent_spawn_client_2.position +
		game.map.agent_spawn_client_3.position + game.map.agent_spawn_client_4.position)/4, 20)
	game.force_camera(
		(game.map.agent_spawn_server_1.position + game.map.agent_spawn_server_2.position +
		game.map.agent_spawn_server_3.position + game.map.agent_spawn_server_4.position)/4, 20)
	($"../ColdBootTimer" as Timer).start()


func _on_cold_boot_timer_timeout() -> void:
	game.animate_fade.rpc(false)
	_track_objective_completion()
	game._update_game_phase(game.GamePhases.SELECTION, false)
	var data : Dictionary = {
		pickup = {
			generate_weapon = true,
			pos_x = 0.0, pos_y = 0.0, pos_z = 0.0,
			server_knows = false,
			client_knows = false,
			wep_name = "",
		},
		weapon = {}
	}
	match game.map.objective:
		game.map.Objectives.CAPTURE_ENEMY_FLAG:
			# create server's flag
			data.pickup.pos_x = game.map.objective_params[0]
			data.pickup.pos_y = game.map.objective_params[1]
			data.pickup.pos_z = game.map.objective_params[2]
			data.pickup.server_knows = true
			data.pickup.client_knows = false
			data.pickup.wep_name = "map_flag_server"
			game.pickup_spawner.spawn(data.pickup)
			# create client's flag
			data.pickup.pos_x = game.map.objective_params[3]
			data.pickup.pos_y = game.map.objective_params[4]
			data.pickup.pos_z = game.map.objective_params[5]
			data.pickup.server_knows = false
			data.pickup.client_knows = true
			data.pickup.wep_name = "map_flag_client"
			game.pickup_spawner.spawn(data.pickup)
		game.map.Objectives.CAPTURE_CENTRAL_FLAG:
			# create central flag
			data.pickup.pos_x = game.map.objective_params[0]
			data.pickup.pos_y = game.map.objective_params[1]
			data.pickup.pos_z = game.map.objective_params[2]
			data.pickup.server_knows = true
			data.pickup.client_knows = true
			data.pickup.wep_name = "map_flag_center"
			game.pickup_spawner.spawn(data.pickup)
		game.map.Objectives.TARGET_DEFEND:
			game.map.objective_params


func determine_sights():
	for agent in ($"../Agents".get_children() as Array[Agent]):
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
	var sight_chance = game.calculate_sight_chance(spotter, spottee.position, spottee.visible_level) * float(not instant_fail)
	if sight_chance > 0.7 or instant_spot: # seent it
		if game.current_game_step - spottee.step_seen < game.REMEMBER_TILL and spottee.step_seen > 0:
			spottee.step_seen = game.current_game_step
			return
		spottee.step_seen = game.current_game_step
		if spotter.player_id == 1:
			spottee.server_knows = true
			game.create_popup("spotted", spottee.position, true)
			spotter.sounds.spotted_agent.play()
		else:
			spottee.client_knows = true
			game.create_popup.rpc_id(GameSettings.other_player_id, "spotted", spottee.position, true)
			spotter.sounds.spotted_agent.play.rpc_id(GameSettings.other_player_id)
	elif sight_chance > 1.0/3.0: # almost seent it
		if spottee.noticed > 0:
			return
		spottee.noticed = 10
		var p_offset = -0.1/sight_chance
		var x_off = randf_range(-p_offset, p_offset)
		var z_off = randf_range(-p_offset, p_offset)
		if spotter.player_id == 1:
			game.create_popup("sight_unknown", spottee.position + Vector3(x_off, 0, z_off))
			spotter.sounds.glanced.play()
		else:
			game.create_popup.rpc_id(GameSettings.other_player_id, "sight_unknown", spottee.position + Vector3(x_off, 0, z_off))
			spotter.sounds.glanced.play.rpc_id(GameSettings.other_player_id)


func try_see_element(spotter : Agent, element : Node3D):
	if element is GamePopup:
		if game.calculate_sight_chance(spotter, element.global_position, 120) > 0.25:
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
	for agent in ($"../Agents".get_children() as Array[Agent]):
		if agent.in_incapacitated_state():
			continue # incapped agents are deaf
		for detected in agent._ears.get_overlapping_areas():
			var audio_event : GameAudioEvent = detected.get_parent()
			if agent.player_id == audio_event.player_id:
				continue # skip same team sources
			if audio_event.heard:
				continue # skip already heard sounds
			if agent.owned():
				game.create_popup("sound_unknown", audio_event.global_position)
				audio_event.play_sound()
			else:
				game.create_popup.rpc_id(GameSettings.other_player_id, "sound_unknown", audio_event.global_position)
				audio_event.play_sound.rpc_id(GameSettings.other_player_id)
		match agent.state:
			Agent.States.WALK when agent.game_steps_since_execute % 40 == 0:
				game.audio_spawner.spawn({
					player = agent.player_id,
					agent = agent.name,
					pos_x = agent.position.x, pos_y = agent.position.y, pos_z = agent.position.z,
					max_rad = 2.0, lifetime = 13, sound_id = "ag_step_quiet",
				})
			Agent.States.RUN when agent.game_steps_since_execute % 20 == 0:
				game.audio_spawner.spawn({
					player = agent.player_id,
					agent = agent.name,
					pos_x = agent.position.x, pos_y = agent.position.y, pos_z = agent.position.z,
					max_rad = 2.75, lifetime = 13, sound_id = "ag_step_loud",
				})
			Agent.States.CROUCH_WALK when agent.game_steps_since_execute % 50 == 0:
				game.audio_spawner.spawn({
					player = agent.player_id,
					agent = agent.name,
					pos_x = agent.position.x, pos_y = agent.position.y, pos_z = agent.position.z,
					max_rad = 2.0, lifetime = 13, sound_id = "ag_step_quiet",
				})
	for audio_event in ($"../AudioEvents".get_children() as Array[GameAudioEvent]):
		audio_event.update()


func _track_objective_completion():
	match game.map.objective:
		GameMap.Objectives.CAPTURE_CENTRAL_FLAG:
			_one_flag_completion()
		#GameMap.Objectives.CAPTURE_ENEMY_FLAG:
			#enemy_flag_completion()

func _one_flag_completion():
	_one_flag_completion_server()
	_one_flag_completion_client()

func _one_flag_completion_server():
	match game.server_progress:
		game.ProgressParts.INTRO:
			game.create_toast_update.rpc(GameRefs.TXT.of_intro, GameRefs.TXT.of_intro, true)
			game.server_progress = game.ProgressParts.NO_ADVANTAGE
		game.ProgressParts.NO_ADVANTAGE: # no one has the flag
			if not game.check_agents_for_weapon(true, "map_flag_center"):
				return
			if not game.check_weapon_holder_exfil(true, "map_flag_center"):
				game.create_toast_update.rpc(GameRefs.TXT.of_y_get, GameRefs.TXT.of_t_get, true)
				game.server_progress = game.ProgressParts.ITEM_HELD
				return
			if not game.has_team_exited(true):
				game.create_toast_update.rpc(GameRefs.TXT.of_cap_agents_remain, GameRefs.TXT.of_cap_agents_remain, true)
				game.server_progress = game.ProgressParts.OBJECTIVE_COMPLETE
				return
			game.create_toast_update.rpc(GameRefs.TXT.of_y_cap_left, GameRefs.TXT.of_t_cap_left, true)
			game.server_progress = game.ProgressParts.SURVIVORS_EXFILTRATED
			return
		game.ProgressParts.ITEM_HELD: # the server team has the flag
			if not game.check_agents_for_weapon(true, "map_flag_center"):
				game.create_toast_update.rpc(GameRefs.TXT.of_y_lost, GameRefs.TXT.of_t_lost, true)
				game.server_progress = game.ProgressParts.NO_ADVANTAGE
				return
			if game.check_weapon_holder_exfil(true, "map_flag_center"):
				if not game.has_team_exited(true):
					game.create_toast_update.rpc(GameRefs.TXT.of_cap_agents_remain, GameRefs.TXT.of_cap_agents_remain, true)
					game.server_progress = game.ProgressParts.OBJECTIVE_COMPLETE
					return
				game.create_toast_update.rpc(GameRefs.TXT.of_y_cap_left, GameRefs.TXT.of_t_cap_left, true)
				game.server_progress = game.ProgressParts.SURVIVORS_EXFILTRATED
				return
		game.ProgressParts.OBJECTIVE_COMPLETE: # a server team member has escaped with the flag
			if game.has_team_exited(true):
				game.create_toast_update.rpc(GameRefs.TXT.mission_success, GameRefs.TXT.mission_failure, true)
				game.server_progress = game.ProgressParts.SURVIVORS_EXFILTRATED


func _one_flag_completion_client():
	match game.client_progress:
		game.ProgressParts.INTRO:
			game.client_progress = game.ProgressParts.NO_ADVANTAGE
		game.ProgressParts.NO_ADVANTAGE: # no one has the flag
			if not game.check_agents_for_weapon(false, "map_flag_center"):
				return
			if not game.check_weapon_holder_exfil(false, "map_flag_center"):
				game.create_toast_update.rpc(GameRefs.TXT.of_t_get, GameRefs.TXT.of_y_get, true)
				game.client_progress = game.ProgressParts.ITEM_HELD
				return
			if not game.has_team_exited(false):
				game.create_toast_update.rpc(GameRefs.TXT.of_cap_agents_remain, GameRefs.TXT.of_cap_agents_remain, true)
				game.client_progress = game.ProgressParts.OBJECTIVE_COMPLETE
				return
			game.create_toast_update.rpc(GameRefs.TXT.of_t_cap_left, GameRefs.TXT.of_y_cap_left, true)
			game.client_progress = game.ProgressParts.SURVIVORS_EXFILTRATED
			return
		game.ProgressParts.ITEM_HELD: # the client team has the flag
			if not game.check_agents_for_weapon(false, "map_flag_center"):
				game.create_toast_update.rpc(GameRefs.TXT.of_t_lost, GameRefs.TXT.of_y_lost, true)
				game.client_progress = game.ProgressParts.NO_ADVANTAGE
				return
			if game.check_weapon_holder_exfil(false, "map_flag_center"):
				if not game.has_team_exited(false):
					game.create_toast_update.rpc(GameRefs.TXT.of_cap_agents_remain, GameRefs.TXT.of_cap_agents_remain, true)
					game.client_progress = game.ProgressParts.OBJECTIVE_COMPLETE
					return
				game.create_toast_update.rpc(GameRefs.TXT.of_t_cap_left, GameRefs.TXT.of_y_cap_left, true)
				game.client_progress = game.ProgressParts.SURVIVORS_EXFILTRATED
				return
		game.ProgressParts.OBJECTIVE_COMPLETE: # a client team member has escaped with the flag
			if game.has_team_exited(false):
				game.create_toast_update.rpc(GameRefs.TXT.mission_failure, GameRefs.TXT.mission_success, true)
				game.client_progress = game.ProgressParts.SURVIVORS_EXFILTRATED
