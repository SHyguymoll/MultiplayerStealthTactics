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
	Lobby.join_game()
	$MainMenu.visible = false
	$HostScreen.visible = true


func _on_host_pressed() -> void:
	Lobby.create_game()
	$MainMenu.visible = false
	$HostScreen.visible = true
	_conditional_create("")


func _create_selector():
	var new_selector : AgentSelector = ag_sel_scene.instantiate()
	new_selector.agent_selected.connect(_conditional_create)
	new_selector.selector_removed.connect(_conditional_remove)
	$HostScreen/AgentHBox.add_child(new_selector)

func _conditional_create(agent_name):
	agent_count += 1
	if agent_count < GameSettings.AGENT_LIMIT:
		_create_selector()
		update_hidden_agents.rpc_id(other_player_id, $HostScreen/AgentHBox.get_child_count())

func _conditional_remove(selector_used : bool):
	if selector_used:
		agent_count -= 1
	if $HostScreen/AgentHBox.get_child_count() == 1: # replace lack of selectors
		_create_selector()
	update_hidden_agents.rpc_id(other_player_id, $HostScreen/AgentHBox.get_child_count())

@rpc("any_peer")
func update_hidden_agents(number : int):
	var change = number - $HostScreen/AgentHBox2.get_child_count()
	if change < 0:
		for extra in $HostScreen/AgentHBox2.get_children().slice(0, abs(change)):
			extra.queue_free()
	else:
		for i in range(change):
			$HostScreen/AgentHBox2.add_child(mp_ag_notif_scene.instantiate())

func _on_player_connect(peer_id, player_info):
	if peer_id == 1:
		return
	other_player_id = peer_id
	update_hidden_agents.rpc_id(other_player_id, $HostScreen/AgentHBox.get_child_count())

func _on_start_pressed() -> void:
	Lobby.load_game.rpc("res://scenes/game.tscn")


func _on_quit_pressed() -> void:
	pass # Replace with function body.
