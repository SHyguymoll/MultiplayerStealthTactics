extends ColorRect

var selected_agents = []
var other_player_id := 0

@onready var _player_agents : ItemList = $HostScreen/PlayerAgents/ItemList
@onready var _enemy_agents : HBoxContainer = $HostScreen/EnemyAgentCounter

func _ready() -> void:
	$HostScreen.visible = false
	$SettingsScreen.visible = false
	$MainMenu.visible = true
	Lobby.player_info = get_agents()
	Lobby.player_connected.connect(_on_player_connect)
	Lobby.player_disconnected.connect(_on_player_disconnect)
	pass


func get_agents():
	return {
		name="test",
		agents=[
			{
				name="agent 1",
				mission_count=0,
				hp=10,
				view_dist=1.0,
				view_arc=1.0,
				items=[],
				weapons=[],
			},
		]
	}

func _on_join_pressed() -> void:
	$HostScreen/Label.text = "Waiting for Host..."
	$HostScreen/ButtonsHbox/Start.visible = false
	other_player_id = 1
	GameSettings.local_mode = false
	Lobby.join_game()
	$MainMenu.visible = false
	$HostScreen.visible = true
	_populate_agent_list()


func _on_host_pressed() -> void:
	$MainMenu.visible = false
	$HostScreen/ButtonsHbox/Ready.visible = false
	GameSettings.local_mode = false
	Lobby.create_game()
	$HostScreen.visible = true
	_populate_agent_list()


func _on_singleplayer_pressed() -> void:
	$MainMenu.visible = false
	$HostScreen/Label.text = "SINGLEPLAYER MODE"
	$HostScreen/ButtonsHbox/Ready.visible = false
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
	if index in selected_agents:
		_player_agents.set_item_text(
				index, _player_agents.get_item_text(index).trim_suffix(" *"))
		selected_agents.erase(index)
		update_hidden_agents.rpc_id(other_player_id, len(selected_agents))
	elif len(selected_agents) < GameSettings.AGENT_LIMIT:
		selected_agents.append(index)
		_player_agents.set_item_text(
				index, _player_agents.get_item_text(index) + " *")
		update_hidden_agents.rpc_id(other_player_id, len(selected_agents))
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
	if other_player_id == 0:
		other_player_id = multiplayer.get_remote_sender_id()
	update_hidden_agents.rpc_id(other_player_id, len(selected_agents))
	if multiplayer.is_server():
		$HostScreen/Label.text = "Player found! " + str(other_player_id)
	else:
		$HostScreen/Label.text = "Host found! " + str(other_player_id)


func _on_player_disconnect(id):
	$HostScreen/Label.text = "Lost connection to {0}!".format([id])

func _on_ready_toggled(toggled_on: bool) -> void:
	_update_readiness.rpc_id(other_player_id, toggled_on)

@rpc("any_peer", "call_remote", "reliable")
func _update_readiness(toggled_on) -> void:
	$HostScreen/ButtonsHbox/Start.disabled = not toggled_on

func _on_start_pressed() -> void:
	Lobby.load_game.rpc("res://scenes/game.tscn")


func _on_quit_pressed() -> void:
	pass # Replace with function body.



