extends ColorRect

@onready var _player_agents : ItemList = $HostScreen/PlayerAgents/ItemList
@onready var _enemy_agents : HBoxContainer = $HostScreen/EnemyAgentCounter

func _ready() -> void:
	GameSettings.selected_agents.clear()
	GameSettings.client_selected_agents.clear()
	GameSettings.server_client_id = 0
	$HostScreen.visible = false
	$SettingsScreen.visible = false
	$MainMenu.visible = true
	Lobby.player_info = get_agents()
	Lobby.player_connected.connect(_on_player_connect)
	Lobby.player_disconnected.connect(_on_player_disconnect)
	pass


func get_agents(): #TODO: replace with loading from a file later
	return {
		name="test",
		agents=[
			{
				name="basic agent",
				mission_count=0,
				health=10,
				view_dist=2.5,
				view_across=1.0,
				eye_strength=0.8,
				hearing_dist=1.5,
				ear_strength=1,
				movement_dist=7.0,
				movement_speed=2.75,
				held_items=["cigar", "box"],
				held_weapons=["pistol", "grenade_smoke"],
			},
		]
	}


func _on_join_pressed() -> void:
	$HostScreen/Label.text = "Waiting for Host..."
	$HostScreen/ButtonsHbox/Ready.visible = true
	$HostScreen/ButtonsHbox/Start.visible = false
	GameSettings.server_client_id = 1
	GameSettings.local_mode = false
	Lobby.join_game()
	$MainMenu.visible = false
	$HostScreen.visible = true
	_populate_agent_list()


func _on_host_pressed() -> void:
	$HostScreen/Label.text = "Waiting for Opponent..."
	$MainMenu.visible = false
	$HostScreen/ButtonsHbox/Ready.visible = false
	$HostScreen/ButtonsHbox/Start.visible = true
	GameSettings.local_mode = false
	Lobby.create_game()
	$HostScreen.visible = true
	_populate_agent_list()


func _on_singleplayer_pressed() -> void:
	$MainMenu.visible = false
	$HostScreen/Label.text = "SINGLEPLAYER MODE"
	$HostScreen/ButtonsHbox/Ready.visible = false
	$HostScreen/ButtonsHbox/Start.visible = true
	$HostScreen/ButtonsHbox/Start.disabled = false
	GameSettings.local_mode = true
	Lobby.create_game(1)
	$HostScreen.visible = true
	_populate_agent_list()


func _populate_agent_list():
	_player_agents.clear()
	for agent in Lobby.player_info.agents:
		_player_agents.add_item(agent.name)


func _on_item_list_item_selected(index: int) -> void:
	if index in GameSettings.selected_agents:
		_player_agents.set_item_text(
				index, _player_agents.get_item_text(index).trim_suffix(" *"))
		GameSettings.selected_agents.erase(index)
		update_hidden_agents.rpc_id(GameSettings.server_client_id, len(GameSettings.selected_agents))
	elif len(GameSettings.selected_agents) < GameSettings.AGENT_LIMIT:
		GameSettings.selected_agents.append(index)
		_player_agents.set_item_text(
				index, _player_agents.get_item_text(index) + " *")
		update_hidden_agents.rpc_id(GameSettings.server_client_id, len(GameSettings.selected_agents))
	else:
		_player_agents.deselect(index)

@rpc("any_peer")
func update_hidden_agents(number : int):
	var change = number - _enemy_agents.get_child_count()
	if change < 0:
		for extra in _enemy_agents.get_children().slice(0, abs(change)):
			extra.queue_free()
	else:
		for i in range(change):
			var new_notif = TextureRect.new()
			new_notif.texture = load("res://assets/sprites/AgentInfoBackground.png")
			_enemy_agents.add_child(new_notif)


func _on_player_connect(peer_id, player_info):
	if peer_id == 1:
		return
	if GameSettings.server_client_id == 0:
		GameSettings.server_client_id = multiplayer.get_remote_sender_id()
	update_hidden_agents.rpc_id(GameSettings.server_client_id, len(GameSettings.selected_agents))
	if multiplayer.is_server():
		$HostScreen/Label.text = "Player found! " + str(GameSettings.server_client_id)
	else:
		$HostScreen/Label.text = "Host found! " + str(GameSettings.server_client_id)


func _on_player_disconnect(id):
	$HostScreen/Label.text = "Lost connection to {0}!".format([id])


func _on_ready_toggled(toggled_on: bool) -> void:
	if not len(GameSettings.selected_agents):
		$HostScreen/ButtonsHbox/Ready.text = "Select your Agents!"
		return
	_update_readiness.rpc_id(GameSettings.server_client_id, toggled_on, GameSettings.selected_agents)

@rpc("any_peer", "call_remote", "reliable")
func _update_readiness(toggled_on : bool, new_selected_agents) -> void: # client-only
	$HostScreen/ButtonsHbox/Start.disabled = not toggled_on
	if toggled_on:
		GameSettings.client_selected_agents = new_selected_agents


func _on_start_pressed() -> void: # server-only
	if not len(GameSettings.selected_agents):
		$HostScreen/ButtonsHbox/Start.text = "Select your Agents!"
		return
	Lobby.load_game.rpc("res://scenes/game.tscn")


func _on_quit_pressed() -> void:
	$HostScreen.visible = false
	$SettingsScreen.visible = false
	$MainMenu.visible = true
	Lobby.remove_multiplayer_peer()
