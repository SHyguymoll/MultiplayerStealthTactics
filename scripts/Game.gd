class_name Game
extends Node3D


var aiming_icon_scene = preload("res://scenes/game_aiming_indicator.tscn")
var tracking_raycast3d_scene = preload("res://scenes/tracking_raycast3d.tscn")
var movement_icon_scene = preload("res://scenes/game_movement_indicator.tscn")
var popup_scene = preload("res://scenes/game_popup.tscn")

@export var action_timeline := {

}
var current_game_step := 0
const REMEMBER_TILL = 150

enum SelectionSteps {
	BASE,
	MOVEMENT,
	AIMING,
}
var selection_step : SelectionSteps = SelectionSteps.BASE

enum Phases {
	SELECTION,
	EXECUTION,
	RESOLUTION,
	COMPLETION,
}
@export var phase : Phases = Phases.SELECTION

@onready var camera : GameCamera = $World/Camera3D

@onready var ui : UI = $UI
@onready var server : GameServer = $MultiplayerHandler

@onready var weapons : Node = $Weapons

@onready var agents : Node3D = $Agents
@onready var pickups : Node3D = $Pickups
@onready var grenades : Node3D = $Grenades
@onready var smokes : Node3D = $Smokes
@onready var indicators : Node3D = $ClientsideIndicators

@onready var popups : Node3D = $Popups
@onready var audio_events : Node3D = $AudioEvents

func start_game(): # Called only on the server.
	server.start_game()

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
	popups.add_child(new_popup)
	if fleeting:
		new_popup.disappear()


func agent_children():
	return (agents.get_children() as Array[Agent])

func append_action_timeline(agent : Agent):
	if not action_timeline.has(current_game_step):
		action_timeline[current_game_step] = {}
	action_timeline[current_game_step][agent.name] = agent.queued_action

func determine_sights():
	for agent in agent_children():
		if agent.player_id != multiplayer.get_unique_id():
			continue
		if agent.in_smoke:
			continue
		var res_arr = agent.look()
		for res in res_arr as Array[Agent.AgentSightResult]:
			if res.spotted_agent:
				if res.spotted_position: # spotted agent was only noticed
					server.set_agent_notice.rpc(res.spotted_agent.name, 10)
					create_popup(GameRefs.POPUP.sight_unknown, res.spotted_position)
				else: # spotted agent was fully seen
					if current_game_step - res.spotted_agent.step_seen < REMEMBER_TILL and res.spotted_agent.step_seen > 0:
						server.set_agent_step_seen.rpc(res.spotted_agent.name, current_game_step)
						continue
					else:
						server.set_agent_step_seen.rpc(res.spotted_agent.name, current_game_step)
						if agent.player_id == 1:
							server.set_agent_server_visibility.rpc(res.spotted_agent.name, true)
						else:
							server.set_agent_client_visibility.rpc(res.spotted_agent.name, true)
						create_popup(GameRefs.POPUP.spotted, res.spotted_agent.position, true)
			else: # spotted agent went unseen completely, disregard
				continue


func determine_sounds():
	for agent in agent_children():
		if agent.in_incapacitated_state():
			continue # incapped agents are deaf
		for audio_effect_position in agent.listen():
			create_popup(GameRefs.POPUP.sound_unknown, audio_effect_position)
		match agent.state:
			Agent.States.WALK when agent.game_steps_since_execute % 40 == 0:
				server.create_sound_effect.rpc(agent.position, agent.player_id, 13, 0.25, 2.0, "ag_step_quiet")
			Agent.States.RUN when agent.game_steps_since_execute % 20 == 0:
				server.create_sound_effect.rpc(agent.position, agent.player_id, 13, 1.5, 2.75, "ag_step_loud")
			Agent.States.CROUCH_WALK when agent.game_steps_since_execute % 50 == 0:
				server.create_sound_effect.rpc(agent.position, agent.player_id, 13, 0.25, 2.0, "ag_step_quiet")
	for audio_event in (audio_events.get_children() as Array[GameAudioEvent]):
		audio_event.update()


func determine_indicator_removals():
	for ind in indicators.get_children():
		if ind is AimingIndicator or ind is MovementIndicator:
			match ind.referenced_agent.action_done:
				Agent.ActionDoneness.SUCCESS:
					ind._succeed()
				Agent.ActionDoneness.FAIL:
					ind._fail()


func verify_game_completeness() -> bool:
	for selector in ui.selectors.get_children() as Array[AgentSelector]:
		if selector.referenced_agent == null: # the only case where the agent is null is the one where the node was destroyed by the server disconnecting
			for selector_to_free in ui.selectors.get_children() as Array[AgentSelector]:
				selector_to_free.queue_free()
			return true
	return false


func selection_phase(delta : float):
	if verify_game_completeness():
		server._update_game_phase(Phases.COMPLETION)
		return
	for selector in ui.selectors.get_children() as Array[AgentSelector]:
		selector.position = camera.unproject_position(
			selector.referenced_agent.position)
		selector.collide.shape.size = Vector2(32, 32) * GameCamera.MAX_FOV/camera.fov


func execution_phase(delta : float):
	determine_cqc_events()
	determine_weapon_events()
	for agent in agent_children():
		agent._game_step(delta)
		agent.in_smoke = false
		if current_game_step - agent.step_seen == REMEMBER_TILL and agent.visible:
			if agent.player_id == 1:
				server.set_agent_client_visibility.rpc(agent.name, false)
				create_popup(GameRefs.POPUP.sight_unknown, agent.position)
			else:
				server.set_agent_server_visibility.rpc(agent.name, false)
				create_popup(GameRefs.POPUP.sight_unknown, agent.position)
		if len(agent.mark_for_drop) > 0:
			var new_drop = {
				pos_x = agent.mark_for_drop.position.x,
				pos_y = agent.mark_for_drop.position.y,
				pos_z = agent.mark_for_drop.position.z,
				server_knows = agent.player_id == 1 or weapons.get_node(str(agent.mark_for_drop.wep_node)).is_map_element(),
				client_knows = agent.player_id != 1 or weapons.get_node(str(agent.mark_for_drop.wep_node)).is_map_element(),
				wep_name = str(agent.mark_for_drop.wep_node),
			}
			server.pickup_spawner.spawn(new_drop)
			#agent.held_weapons.erase(agent.mark_for_drop.wep_node)
			server.remove_weapon_from_agent.rpc(agent.name, agent.mark_for_drop.wep_node)
			agent.mark_for_drop.clear()
		if agent.try_grab_pickup and len(agent.queued_action) > 1:
			if pickups.get_node_or_null(str(agent.queued_action[1])) != null:
				pickups.get_node(str(agent.queued_action[1])).queue_free()
			agent.try_grab_pickup = false
		if agent.state == Agent.States.DEAD and len(agent.held_weapons) > 1:
			var new_drop = {
				pos_x = agent.global_position.x + (randf() - 0.5),
				pos_y = agent.global_position.y,
				pos_z = agent.global_position.z + (randf() - 0.5),
				server_knows = agent.player_id == 1 or weapons.get_node(str(agent.held_weapons[1])).is_map_element(),
				client_knows = agent.player_id != 1 or weapons.get_node(str(agent.held_weapons[1])).is_map_element(),
				wep_name = str(agent.held_weapons[1]),
			}
			server.pickup_spawner.spawn(new_drop)
			server.remove_weapon_from_agent.rpc(agent.name, new_drop.wep_name)
		if agent.mark_for_grenade_throw:
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
	for grenade in (grenades.get_children() as Array[Grenade]):
		grenade._tick()
		if grenade.explode:
			match grenade.wep_id:
				"grenade_frag":
					for exploded in grenade._explosion_hitbox.get_overlapping_areas():
						var attacked : Agent = exploded.get_parent()
						if attacked.in_prone_state():
							continue # prone agents dodge explosions for Reasons™
						server.damage_agent.rpc(attacked.name, 2, false)
						server.create_sound_effect.rpc(attacked.position, attacked.player_id, 5, 0.75, 2.5, "ag_hurt")
					server.create_sound_effect.rpc(grenade.global_position, grenade.player_id, 10, 0.1, 5.0, "grenade_frag")
				"grenade_smoke":
					server.smoke_spawner.spawn({
						pos_x = grenade.position.x,
						pos_y = grenade.position.y,
						pos_z = grenade.position.z,
						wep_name = grenade.name,
					})
					server.create_sound_effect.rpc(grenade.global_position, grenade.player_id, 10, 0.1, 5.0, "grenade_smoke")
				"grenade_noise":
					server.create_sound_effect.rpc(grenade.global_position, grenade.player_id, 10, 0.1, 10.0, "grenade_frag")
			server.grenades_in_existence.erase(grenade.name)
			grenade.queue_free()
	for smoke in (smokes.get_children() as Array[Smoke]):
		smoke._tick()
		for caught in smoke.col_area.get_overlapping_areas():
			caught.get_parent().in_smoke = true
		smoke.queue_free()
	for pickup in (pickups.get_children() as Array[WeaponPickup]):
		pickup._animate(delta)
	current_game_step += 1
	determine_sights()
	determine_sounds()
	determine_indicator_removals()
	for agent in agent_children():
		if agent.action_done == Agent.ActionDoneness.NOT_DONE:
			return
	print("{0}: all agents done trans to resolution".format([str(multiplayer.get_unique_id())]))
	update_game_phase(Phases.RESOLUTION)


func completion_phase(delta):
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


func update_game_phase(new_phase: Phases):
	phase = new_phase
	transition_phase()


func transition_phase():
	print("{0}: {1}".format([str(multiplayer.get_unique_id()), str(Phases.keys()[phase])]))
	match phase:
		Phases.SELECTION:
			ui.round_ended.play()
			ui.phase_label.text = "SELECT ACTIONS"
			ui.execute_button.disabled = false
			ui.execute_button.text = "EXECUTE INSTRUCTIONS"
			ui.show_hud()
			if ui.selectors.get_child_count() == 0:
				ui._on_execute_pressed() # run execute since the player can't do anything
			if not multiplayer.is_server(): # Client bouncer for server to do business
				return
			# update exfiltrations
			if server.server_progress == server.ProgressParts.ITEM_HELD:
				var can_exfil = false
				for detect in server.game_map.server_exfiltrate_zone.get_overlapping_areas():
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
					for detect in server.game_map.server_exfiltrate_zone.get_overlapping_areas():
						var actual_agent : Agent = detect.get_parent()
						if actual_agent.state == Agent.States.DEAD:
							continue
						server.exfiltration_queue.append(actual_agent.name)
			elif server.server_progress == server.ProgressParts.OBJECTIVE_COMPLETE:
				for detect in server.game_map.server_exfiltrate_zone.get_overlapping_areas():
					var actual_agent : Agent = detect.get_parent()
					if actual_agent.state == Agent.States.DEAD:
						continue
					server.exfiltration_queue.append(actual_agent.name)
			if server.client_progress == server.ProgressParts.ITEM_HELD:
				var can_exfil = false
				for detect in server.game_map.client_exfiltrate_zone.get_overlapping_areas():
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
					for detect in server.game_map.client_exfiltrate_zone.get_overlapping_areas():
						var actual_agent : Agent = detect.get_parent()
						if actual_agent.state == Agent.States.DEAD:
							continue
						server.exfiltration_queue.append(actual_agent.name)
			elif server.client_progress == server.ProgressParts.OBJECTIVE_COMPLETE:
				for detect in server.game_map.client_exfiltrate_zone.get_overlapping_areas():
					var actual_agent : Agent = detect.get_parent()
					if actual_agent.state == Agent.States.DEAD:
						continue
					server.exfiltration_queue.append(actual_agent.name)
			for agent_name in server.exfiltration_queue:
				(agents.get_node(str(agent_name)) as Agent).exfiltrate()
			server.track_objective_completion() # objective based updates here
		Phases.EXECUTION:
			ui.hurry_up.visible = false
			for agent in agent_children():
				agent.action_text = ""
			ui.update_text()
			ui.phase_label.text = "EXECUTING ACTIONS..."
			server.server_ready_bool = false
			server.client_ready_bool = false
			# populate agents with actions, as well as action_timeline
			for agent in agent_children():
				agent.agent_is_done.rpc(Agent.ActionDoneness.NOT_DONE)
				append_action_timeline(agent)
				agent.perform_action()
			await get_tree().create_timer(0.10).timeout
		Phases.RESOLUTION:
			# create selectors and otherwise prepare for selection or completion
			var server_team_dead = true
			var client_team_dead = true
			for ag in agent_children():
				ag.action_done = Agent.ActionDoneness.NOT_DONE
				ag.ungrabbable = false
				server.set_agent_action.rpc(ag.name, [])
				if ag.is_multiplayer_authority() and not ag.in_incapacitated_state():
					ui.create_agent_selector(ag.name)
					ag.flash_outline(Color.ORCHID)
				if ag.state != Agent.States.DEAD:
					if ag.player_id == 1:
						server_team_dead = false
					else:
						client_team_dead = false
			if not server.player_has_won(server_team_dead, client_team_dead): # win conditions
				update_game_phase(Phases.SELECTION)
				return
			else:
				update_game_phase(Phases.COMPLETION)
				return
		Phases.COMPLETION:
			save_replay()
			if not server.sent_final_message:
				server.create_toast_update.rpc("GAME OVER", "GAME OVER", true, Color.INDIGO - Color(0, 0, 0, 1 - 0.212))
				server.animate_fade.rpc()
				server.sent_final_message = true
			ui.pause_menu_phase.text = "EXIT"
			ui.open_pause_menu()
			ui.pause_menu_no.visible = false
			ui.pause_menu_no.disabled = true


func _physics_process(delta: float) -> void:
	if phase == Phases.SELECTION: # Server and Client can do things here
		selection_phase(delta)
	if multiplayer.is_server(): # Server only handles this
		match phase:
			Phases.EXECUTION:
				execution_phase(delta)
			#Phases.RESOLUTION: only needed for one moment, written here for consistency
				#resolution_step()
			Phases.COMPLETION:
				completion_phase(delta)


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
		server.damage_agent.rpc(grabbee.name, 3, true)
		grabbee.step_seen = current_game_step

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
				server.create_sound_effect.rpc(agent.position, agent.player_id, 10, 0.25, 0.5, "pistol")
			"rifle":
				attackers[agent] = [return_attacked(agent, slide_end_pos(agent._body.global_position, agent.queued_action[1], 0.2)),return_attacked(agent, slide_end_pos(agent._body.global_position, agent.queued_action[1], -0.2)),]
				server.create_sound_effect.rpc(agent.position, agent.player_id, 10, 0.5, 1.5, "rifle")
			"shotgun":
				attackers[agent] = [
					return_attacked(agent, slide_end_pos(agent._body.global_position, agent.queued_action[1], 1.0)),
					return_attacked(agent, agent.queued_action[1]),
					return_attacked(agent, slide_end_pos(agent._body.global_position, agent.queued_action[1], -1.0)),
					]
				server.create_sound_effect.rpc(agent.position, agent.player_id, 15, 2.25, 3.5, "shotgun")
	for attacker in (attackers.keys() as Array[Agent]):
		attacker.state = Agent.States.USING_WEAPON
		for hit in attackers[attacker]:
			if hit[0] == null: # hit a wall, make a sound event on the wall
				server.create_sound_effect.rpc(hit[1], attacker.player_id, 4, 0.5, 2, "projectile_bounce")
			else:
				if not (hit[0] as Area3D).get_parent() is Agent: # still hit a wall
					server.create_sound_effect.rpc(hit[1], attacker.player_id, 4, 0.5, 2, "projectile_bounce")
				else: # actually hit an agent
					var attacked : Agent = (hit[0] as Area3D).get_parent()
					if attacker.player_id == attacked.player_id:
						continue # same team can block bullets but won't take damage
					if attacked.stun_time > 0:
						continue # skip already attacked agents
					if attacked.in_prone_state() or attacked.state == Agent.States.DEAD:
						continue # skip prone agents
					server.damage_agent.rpc(attacked.name, GameRefs.get_held_weapon_attribute(attacker, attacker.selected_weapon, "damage"), false)
					server.create_sound_effect.rpc(attacked.position, attacked.player_id, 5, 0.75, 2.5, "ag_hurt")


func _on_radial_menu_decision_made(decision_array: Array) -> void:
	var ref_ag : Agent = ui.pop_radial_menu_agent()
	if indicators.get_node_or_null(String(ref_ag.name)): # remove prev indicator
		indicators.get_node(String(ref_ag.name))._neutral()
		indicators.get_node(String(ref_ag.name)).name += "_neutralling"
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
	ref_ag.action_text = final_text_string
	ui.update_text()
	ui.execute_button.visible = true
	ui.execute_button.disabled = false


func _on_radial_menu_movement_decision_made(decision_array: Array) -> void:
	var ref_ag : Agent = ui.pop_radial_menu_agent()
	if indicators.get_node_or_null(String(ref_ag.name)):
		indicators.get_node(String(ref_ag.name))._neutral()
		indicators.get_node(String(ref_ag.name)).name += "_neutralling"
	server.set_agent_action.rpc(ref_ag.name, decision_array)
	ref_ag.queued_action = decision_array
	selection_step = SelectionSteps.MOVEMENT
	var new_indicator = movement_icon_scene.instantiate()
	new_indicator.referenced_agent = ref_ag
	new_indicator.name = ref_ag.name
	indicators.add_child(new_indicator)
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
	if indicators.get_node_or_null(String(ref_ag.name)):
		indicators.get_node(String(ref_ag.name))._neutral()
		indicators.get_node(String(ref_ag.name)).name += "_neutralling"
	server.set_agent_action.rpc(ref_ag.name, decision_array)
	ref_ag.queued_action = decision_array
	selection_step = SelectionSteps.AIMING
	var new_indicator = aiming_icon_scene.instantiate()
	new_indicator.referenced_agent = ref_ag
	new_indicator.name = ref_ag.name
	indicators.add_child(new_indicator)
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


func _on_radial_menu_no_decision_made() -> void:
	ui.update_text()
	ui.execute_button.visible = true
	ui.execute_button.disabled = false


func save_replay():
	action_timeline[current_game_step] = "END"
	var end_time = str(int(Time.get_unix_time_from_system()))
	if DirAccess.open("user://replays") == null:
		DirAccess.make_dir_absolute("user://replays")
	var new_replay = FileAccess.open("user://replays/" + server.start_time + "_" + end_time + ".mstr", FileAccess.WRITE)
	new_replay.store_string(JSON.stringify(action_timeline))


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


func _on_pickup_spawner_despawned(node: Node) -> void:
	node.queue_free()


func _on_yes_forfeit_pressed() -> void:
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
	save_replay()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
