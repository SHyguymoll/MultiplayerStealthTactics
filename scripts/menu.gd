extends ColorRect

var mp_ag_notif_scene = preload("res://scenes/agent_notifier.tscn")
var ag_sel_scene = preload("res://scenes/agent_selector.tscn")
var agent_count = 0
var other_player_id := 0

func _ready() -> void:
	$HostScreen.visible = false
	$SettingsScreen.visible = false
	$MainMenu.visible = true
	Lobby.player_info = get_agents()
	Lobby.player_connected.connect(_on_player_connect)
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
	$HostScreen/Label.visible = false
	Lobby.join_game()
	$MainMenu.visible = false
	$HostScreen.visible = true
	_create_selectors(4)


func _on_host_pressed() -> void:
	Lobby.create_game()
	$MainMenu.visible = false
	$HostScreen.visible = true
	_create_selectors(4)


func _create_selectors(selector_count : int):
	if selector_count < 1:
		printerr("invalid number of selectors, must be positive integer")
		return
	var new_selector : AgentSelector = ag_sel_scene.instantiate()
	new_selector.name = "1"
	new_selector.agent_selected.connect(_add_agent)
	new_selector.selector_removed.connect(_remove_agent)
	$HostScreen/AgentHBox.add_child(new_selector)
	new_selector.opt_but.disabled = false
	var prev_selector = new_selector
	for i in range(1, selector_count):
		new_selector = ag_sel_scene.instantiate()
		new_selector.name = str(i)
		new_selector.agent_selected.connect(_add_agent)
		new_selector.selector_removed.connect(_remove_agent)
		prev_selector.agent_selected.connect(new_selector.enable_opt_button)
		$HostScreen/AgentHBox.add_child(new_selector)
		prev_selector = new_selector


func _add_agent(agent_name):
	agent_count += 1
	update_hidden_agents.rpc_id(other_player_id, agent_count)

func _remove_agent():
	agent_count -= 1
	update_hidden_agents.rpc_id(other_player_id, agent_count)

@rpc("any_peer")
func update_hidden_agents(number : int):
	var change = number - $HostScreen/AgentHBox2.get_child_count()
	if change < 0:
		for extra in $HostScreen/AgentHBox2.get_children().slice(0, abs(change)):
			extra.queue_free()
	else:
		for i in range(change):
			$HostScreen/AgentHBox2.add_child(mp_ag_notif_scene.instantiate())

@rpc
func _on_player_connect(peer_id, player_info):
	if peer_id == 1:
		return
	other_player_id = multiplayer.get_remote_sender_id()
	update_hidden_agents.rpc_id(other_player_id, agent_count)
	$HostScreen/Label.text = "Player found!"

func _on_start_pressed() -> void:
	Lobby.load_game.rpc("res://scenes/game.tscn")


func _on_quit_pressed() -> void:
	pass # Replace with function body.
