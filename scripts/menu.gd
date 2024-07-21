extends ColorRect

@onready var _player_agents : ItemList = $HostScreen/PlayerAgents/ItemList
@onready var _enemy_agents : HBoxContainer = $HostScreen/EnemyAgentCounter

@onready var _ready_button : Button = $HostScreen/ButtonsHbox/Ready
@onready var _start_button : Button = $HostScreen/ButtonsHbox/Start
@onready var _text_reset_timer : Timer = $TextReset

func _ready() -> void:
	GameSettings.selected_agents.clear()
	GameSettings.client_selected_agents.clear()
	GameSettings.other_player_id = 0
	$HostScreen.visible = false
	$SettingsScreen.visible = false
	$MainMenu.visible = true
	Lobby.player_info = get_agents()
	Lobby.player_connected.connect(_on_player_connect)
	Lobby.player_disconnected.connect(_on_player_disconnect)
	pass


#func _process(delta: float) -> void:
	#$HostScreen/DebugPrint.text = str(GameSettings.selected_agents) + "\n" + str(GameSettings.client_selected_agents) + "\n" + str(Lobby.players)


func get_agents(): #TODO: replace with loading from a file later
	return {
		name="test", # the player's name
		agents=[
			{
				name="stealthy", # the agent's name
				mission_count=0, # the number of missions that this agent has been used in
				health=10, # the agent's health and stun health (div by 2 and round down for stun)
				view_dist=2.5, # how far the view cone extends from the agent
				view_across=1.0, # how wide the view cone base is
				eye_strength=0.2, # the strength of the agent's vision as elements get closer
# (note, this is within the view cone, calculated here: https://www.desmos.com/calculator/azk19m9ik3)
				hearing_dist=1.5, # the radius of the hearing cylinder
				# calculate this with the vision calculator by setting v to 100
				movement_dist=7.0, # how far the agent can move in a single step
				movement_speed=2.75, # how fast the agent moves
				held_items=["cigar", "box"], # the items that the agent starts with
				held_weapons=["pistol", "grenade_smoke"], # the weapons that the agent starts with
			},
			{
				name="loud",
				mission_count=0,
				health=10,
				view_dist=2.5,
				view_across=1.0,
				eye_strength=0.2,
				hearing_dist=1.5,
				movement_dist=7.0,
				movement_speed=2.75,
				held_items=["cigar", "box"],
				held_weapons=["shotgun", "rifle"],
			},
		]
	}


func _on_join_pressed() -> void:
	$HostScreen/Label.text = "Waiting for Host..."
	_ready_button.visible = true
	_start_button.visible = false
	GameSettings.other_player_id = 1
	GameSettings.local_mode = false
	Lobby.join_game()
	$MainMenu.visible = false
	$HostScreen.visible = true
	_populate_agent_list()


func _on_host_pressed() -> void:
	$HostScreen/Label.text = "Waiting for Opponent..."
	$MainMenu.visible = false
	_ready_button.visible = false
	_start_button.visible = true
	GameSettings.local_mode = false
	Lobby.create_game()
	$HostScreen.visible = true
	_populate_agent_list()


func _on_singleplayer_pressed() -> void:
	$MainMenu.visible = false
	$HostScreen/Label.text = "SINGLEPLAYER MODE"
	_ready_button.visible = false
	_start_button.visible = true
	_start_button.disabled = false
	GameSettings.local_mode = true
	Lobby.create_game(1)
	$HostScreen.visible = true
	_populate_agent_list()


func _populate_agent_list():
	_player_agents.clear()
	for agent in Lobby.player_info.agents:
		_player_agents.add_item(agent.name)


func _on_item_list_item_selected(index: int) -> void:
	if multiplayer.is_server():
		if index in GameSettings.selected_agents:
			_player_agents.set_item_text(
					index, _player_agents.get_item_text(index).trim_suffix(" *"))
			remove_agent.rpc(index, true)
		elif len(GameSettings.selected_agents) < GameSettings.AGENT_LIMIT:
			_player_agents.set_item_text(
					index, _player_agents.get_item_text(index) + " *")
			add_agent.rpc(index, true)
		else:
			_player_agents.deselect(index)
	else:
		if index in GameSettings.client_selected_agents:
			_player_agents.set_item_text(
					index, _player_agents.get_item_text(index).trim_suffix(" *"))
			remove_agent.rpc(index, false)
		elif len(GameSettings.client_selected_agents) < GameSettings.AGENT_LIMIT:
			_player_agents.set_item_text(
					index, _player_agents.get_item_text(index) + " *")
			add_agent.rpc(index, false)
		else:
			_player_agents.deselect(index)


@rpc("any_peer", "call_local")
func add_agent(agent_index, is_server):
	if is_server:
		GameSettings.selected_agents.append(agent_index)
		if not multiplayer.is_server():
			var new_notif = TextureRect.new()
			new_notif.texture = load("res://assets/sprites/AgentInfoBackground.png")
			_enemy_agents.add_child(new_notif)
	else:
		GameSettings.client_selected_agents.append(agent_index)
		if multiplayer.is_server():
			var new_notif = TextureRect.new()
			new_notif.texture = load("res://assets/sprites/AgentInfoBackground.png")
			_enemy_agents.add_child(new_notif)


@rpc("any_peer", "call_local")
func remove_agent(agent_index, is_server):
	if is_server:
		GameSettings.selected_agents.erase(agent_index)
		if not multiplayer.is_server():
			_enemy_agents.get_child(-1).queue_free()
	else:
		GameSettings.client_selected_agents.erase(agent_index)
		if multiplayer.is_server():
			_enemy_agents.get_child(-1).queue_free()


@rpc("authority", "call_remote")
func synchronize_agents(selected : Array):
	for agent_index in selected:
		GameSettings.selected_agents.append(agent_index)
		var new_notif = TextureRect.new()
		new_notif.texture = load("res://assets/sprites/AgentInfoBackground.png")
		_enemy_agents.add_child(new_notif)


func _on_player_connect(peer_id, player_info):
	if peer_id == 1: # self joined, disregard
		return
	GameSettings.other_player_id = multiplayer.get_remote_sender_id()
	if multiplayer.is_server():
		$HostScreen/Label.text = "Player found! " + str(GameSettings.other_player_id)
		synchronize_agents.rpc_id(GameSettings.other_player_id, GameSettings.selected_agents)
	else:
		$HostScreen/Label.text = "Host found! " + str(GameSettings.other_player_id)


func _on_player_disconnect(id):
	$HostScreen/Label.text = "Lost connection to {0}!".format([id])
	for extra in _enemy_agents.get_children():
		extra.queue_free()


func _on_ready_toggled(toggled_on: bool) -> void:
	if not len(GameSettings.client_selected_agents):
		_ready_button.text = "Select your Agents!"
		_ready_button.set_pressed_no_signal(false)
		_text_reset_timer.start()
		return
	_update_readiness.rpc_id(1, toggled_on)

@rpc("any_peer", "call_remote", "reliable")
func _update_readiness(toggled_on : bool) -> void: # client-only
	_start_button.disabled = not toggled_on


func _on_start_pressed() -> void: # server-only
	if not len(GameSettings.selected_agents):
		_start_button.text = "Select your Agents!"
		_text_reset_timer.start()
		return
	Lobby.load_game.rpc("res://scenes/game.tscn")


func _on_quit_pressed() -> void:
	$HostScreen.visible = false
	$SettingsScreen.visible = false
	$MainMenu.visible = true
	if not multiplayer.is_server():
		Lobby.players.clear()
	else:
		Lobby.players.erase(GameSettings.other_player_id)
	Lobby.remove_multiplayer_peer()
	GameSettings.other_player_id = 0
	get_tree().reload_current_scene()


func _on_text_reset_timeout() -> void:
	_ready_button.text = "READY"
	_start_button.text = "START"
