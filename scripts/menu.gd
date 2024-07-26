extends ColorRect

@onready var _player_agents : ItemList = $HostScreen/PlayerAgents/ItemList
@onready var _enemy_agents : HBoxContainer = $HostScreen/EnemyAgentCounter

@onready var _ready_button : Button = $HostScreen/ButtonsHbox/Ready
@onready var _start_button : Button = $HostScreen/ButtonsHbox/Start
@onready var _text_reset_timer : Timer = $HostScreen/TextReset

var user_data = {}
var agents = []
func _ready() -> void:
	GameSettings.selected_agents.clear()
	GameSettings.client_selected_agents.clear()
	GameSettings.other_player_id = 0
	$HostScreen.visible = false
	$SettingsScreen.visible = false
	$MainMenu.visible = true
	load_user()
	load_agents()
	Lobby.player_info = {
		name = user_data.name,
		agents = agents,
	}
	_populate_agent_list()
	Lobby.player_connected.connect(_on_player_connect)
	Lobby.player_disconnected.connect(_on_player_disconnect)
	pass


#func _process(delta: float) -> void:
	#$HostScreen/DebugPrint.text = str(GameSettings.selected_agents) + "\n" + str(GameSettings.client_selected_agents) + "\n" + str(Lobby.players)


func save_user():
	var file = FileAccess.open("user://player.mstd", FileAccess.WRITE)
	var json_data = JSON.stringify(user_data)
	file.store_string(json_data)


func load_user():
	var file = FileAccess.open("user://player.mstd", FileAccess.READ)
	if file == null:
		user_data = {
			name = "XO " + str(int(Time.get_unix_time_from_system()) % 1000) + "-" + str(randi_range(0, 10)),
			mission_count = 0,
			victory_count = 0,
		}
		save_user()
		file = FileAccess.open("user://player.mstd", FileAccess.READ)
	user_data = JSON.parse_string(file.get_as_text(true))


func save_agents():
	var file = FileAccess.open("user://agents.mstd", FileAccess.WRITE)
	var json_data = JSON.stringify(agents)
	file.store_string(json_data)


func load_agents():
	var file = FileAccess.open("user://agents.mstd", FileAccess.READ)
	if file == null:
		agents = [
			{
				name="Smoking Shark", # the agent's name
				mission_count=0, # the number of missions that this agent has been used in
				health=10, # the agent's health
# value between 5 and 13
				stun_health=5, # the agent's stun health
# value between 3 and 8
				view_dist=2.5, # how far the view cone extends from the agent
# value between 2.00 and 3.50
				view_across=1.0, # how wide the view cone base is
# value between 0.80 and 1.20
				eye_strength=0.4, # the strength of the agent's vision as elements get closer
# value between 0.30 and 0.60
# (note, this is within the view cone, calculated here: https://www.desmos.com/calculator/azk19m9ik3)
				hearing_dist=1.5, # the radius of the hearing cylinder
# value between 0.80 and 1.65
				movement_dist=5.50, # how far the agent can move in a single step
# value between 4.00 and 9.00
				movement_speed=2.75, # how fast the agent moves
# value between 1.25 and 3.00
				held_items=["cigar", "box"], # the items that the agent starts with
# no more than 2
				held_weapons=["pistol", "grenade_smoke"], # the weapons that the agent starts with
# no more than 2
			},
		]
		save_agents()
		file = FileAccess.open("user://agents.mstd", FileAccess.READ)
	var agent_file = JSON.parse_string(file.get_as_text(true))
	if agent_file != null:
		agents = agent_file


func _on_join_pressed() -> void:
	$HostScreen/Label.text = "Waiting for Host..."
	_ready_button.visible = true
	_start_button.visible = false
	GameSettings.other_player_id = 1
	GameSettings.local_mode = false
	Lobby.join_game()
	$MainMenu.visible = false
	$HostScreen.visible = true


func _on_host_pressed() -> void:
	$HostScreen/Label.text = "Waiting for Opponent..."
	$MainMenu.visible = false
	_ready_button.visible = false
	_start_button.visible = true
	GameSettings.local_mode = false

	Lobby.create_game()
	$HostScreen.visible = true


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
