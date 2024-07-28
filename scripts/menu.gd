extends ColorRect

@onready var _player_agents : ItemList = $HostScreen/PlayerAgents/ItemList
@onready var _enemy_agents : HBoxContainer = $HostScreen/EnemyAgentCounter

@onready var _ready_button : Button = $HostScreen/ButtonsHbox/Ready
@onready var _start_button : Button = $HostScreen/ButtonsHbox/Start
@onready var _text_reset_timer : Timer = $HostScreen/TextReset

@onready var _review_agents_list : ItemList = $ReviewScreen/ReviewItemList
@onready var _review_items_list : ItemList = $ReviewScreen/AgentDetails/HBox/Items
@onready var _review_weapons_list : ItemList = $ReviewScreen/AgentDetails/HBox/Weapons

var review_selected_agent : int = -1

var user_data = {}
var agents = []

func _ready() -> void:
	GameSettings.selected_agents.clear()
	GameSettings.client_selected_agents.clear()
	GameSettings.other_player_id = 0
	$HostScreen.visible = false
	$SettingsScreen.visible = false
	$ReviewScreen.visible = false
	$MainMenu.visible = true
	$MainMenu/VBoxContainer/HostH/CheckBox.button_pressed = false
	load_user()
	load_agents()
	if len(GameSettings.winning_agents) > 0:
		for winner in GameSettings.winning_agents:
			for check in agents:
				if check.name == winner:
					check.mission_count += 1
					break
		GameSettings.winning_agents = []
		save_agents()
	_populate_agent_list()
	Lobby.player_connected.connect(_on_player_connect)
	Lobby.player_disconnected.connect(_on_player_disconnect)
	pass


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
				name="Smoking Shark_32", # the agent's name
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
	if $MainMenu/VBoxContainer/JoinH/LineEdit.text.is_empty():
		$MainMenu/VBoxContainer/JoinH/LineEdit.text = $MainMenu/VBoxContainer/JoinH/LineEdit.placeholder_text
	$HostScreen/Label.text = "Waiting for Host..."
	_ready_button.visible = true
	_start_button.visible = false
	GameSettings.other_player_id = 1
	Lobby.player_info = {
		name = user_data.name,
		agents = agents,
	}
	if Lobby.join_game($MainMenu/VBoxContainer/JoinH/LineEdit.text) == 0:
		$MainMenu.visible = false
		$HostScreen.visible = true
	else:
		$MainMenu/VBoxContainer/JoinH/Join.text = "IP ERROR"
		$MainMenu/TextChangeTimer.start()


func _on_host_pressed() -> void:
	if len(agents) == 0:
		$MainMenu/VBoxContainer/HostH/Host.text = "Recruit an Agent first!"
		$MainMenu/VBoxContainer/JoinH/Join.text = "Recruit an Agent first!"
		$MainMenu/TextChangeTimer.start()
		return
	$HostScreen/Label.text = "Waiting for Opponent... "
	$MainMenu.visible = false
	_ready_button.visible = false
	_start_button.visible = true
	Lobby.player_info = {
		name = user_data.name,
		agents = agents,
	}
	Lobby.create_game(0, $MainMenu/VBoxContainer/HostH/CheckBox.button_pressed)
	$HostScreen/Label.text += Lobby.extern_addr
	if Lobby.extern_addr.is_empty():
		$HostScreen/Label.text += "FUCK SOMETHING BROKE"

	$HostScreen.visible = true


func _on_review_agents_pressed() -> void:
	$MainMenu.visible = false
	$ReviewScreen.visible = true
	review_selected_agent = -1
	$ReviewScreen/FireAgent.disabled = true


func _populate_agent_list():
	_player_agents.clear()
	_review_agents_list.clear()
	for agent in agents:
		_player_agents.add_item(agent.name)
		_review_agents_list.add_item(agent.name)


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


func _on_player_connect(peer_id, _player_info):
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
		Lobby.destroy_upnp_thing()
	Lobby.remove_multiplayer_peer()
	GameSettings.other_player_id = 0
	get_tree().reload_current_scene()


func _on_back_pressed() -> void:
	$SettingsScreen.visible = false
	$ReviewScreen.visible = false
	$ReviewScreen/FireAgent.disabled = true
	review_selected_agent = -1
	$MainMenu.visible = true


func _on_text_reset_timeout() -> void:
	_ready_button.text = "READY"
	_start_button.text = "START"

func _on_review_item_list_item_selected(index: int) -> void:
	if review_selected_agent > -1:
		_review_agents_list.set_item_text(review_selected_agent, _review_agents_list.get_item_text(review_selected_agent).trim_suffix(" <"))
	review_selected_agent = index
	_review_agents_list.set_item_text(index, _review_agents_list.get_item_text(index) + " <")
	$ReviewScreen/FireAgent.disabled = false


func _process(_d: float) -> void:
	if review_selected_agent > -1:
		$ReviewScreen/AgentDetails/MissionCount.text = "MISSION COUNT: " + str(agents[review_selected_agent]["mission_count"])
		$ReviewScreen/AgentDetails/Health/HBoxContainer/HSlider.value = lerpf(
			$ReviewScreen/AgentDetails/Health/HBoxContainer/HSlider.value,
			agents[review_selected_agent]["health"], 0.2
		)
		$ReviewScreen/AgentDetails/StunHealth/HBoxContainer/HSlider.value = lerpf(
			$ReviewScreen/AgentDetails/StunHealth/HBoxContainer/HSlider.value,
			agents[review_selected_agent]["stun_health"], 0.2
		)
		$ReviewScreen/AgentDetails/ViewDist/HBoxContainer/HSlider.value = lerpf(
			$ReviewScreen/AgentDetails/ViewDist/HBoxContainer/HSlider.value,
			agents[review_selected_agent]["view_dist"], 0.2
		)
		$ReviewScreen/AgentDetails/ViewAcross/HBoxContainer/HSlider.value = lerpf(
			$ReviewScreen/AgentDetails/ViewAcross/HBoxContainer/HSlider.value,
			agents[review_selected_agent]["view_across"], 0.2
		)
		$ReviewScreen/AgentDetails/EyeStrength/HBoxContainer/HSlider.value = lerpf(
			$ReviewScreen/AgentDetails/EyeStrength/HBoxContainer/HSlider.value,
			agents[review_selected_agent]["eye_strength"], 0.2
		)
		$ReviewScreen/AgentDetails/HearingDist/HBoxContainer/HSlider.value = lerpf(
			$ReviewScreen/AgentDetails/HearingDist/HBoxContainer/HSlider.value,
			agents[review_selected_agent]["hearing_dist"], 0.2
		)
		$ReviewScreen/AgentDetails/MovementDist/HBoxContainer/HSlider.value = lerpf(
			$ReviewScreen/AgentDetails/MovementDist/HBoxContainer/HSlider.value,
			agents[review_selected_agent]["movement_dist"], 0.2
		)
		$ReviewScreen/AgentDetails/MovementSpeed/HBoxContainer/HSlider.value = lerpf(
			$ReviewScreen/AgentDetails/MovementSpeed/HBoxContainer/HSlider.value,
			agents[review_selected_agent]["movement_speed"], 0.2
		)

		for item in range(_review_items_list.item_count):
			_review_items_list.set_item_text(item, "")
		for item in range(_review_weapons_list.item_count):
			_review_weapons_list.set_item_text(item, "")
		for itm_name in agents[review_selected_agent]["held_items"]:
			_review_items_list.set_item_text(reverse_get_index_from_name(itm_name), "^")
		for wep_name in agents[review_selected_agent]["held_weapons"]:
			_review_weapons_list.set_item_text(reverse_get_index_from_name(wep_name), "^")
	else:
		$ReviewScreen/AgentDetails/MissionCount.text = "MISSION COUNT: -"
		$ReviewScreen/AgentDetails/Health/HBoxContainer/HSlider.value = $ReviewScreen/AgentDetails/Health/HBoxContainer/HSlider.min_value
		$ReviewScreen/AgentDetails/StunHealth/HBoxContainer/HSlider.value = $ReviewScreen/AgentDetails/StunHealth/HBoxContainer/HSlider.min_value
		$ReviewScreen/AgentDetails/ViewDist/HBoxContainer/HSlider.value = $ReviewScreen/AgentDetails/ViewDist/HBoxContainer/HSlider.min_value
		$ReviewScreen/AgentDetails/ViewAcross/HBoxContainer/HSlider.value = $ReviewScreen/AgentDetails/ViewAcross/HBoxContainer/HSlider.min_value
		$ReviewScreen/AgentDetails/EyeStrength/HBoxContainer/HSlider.value = $ReviewScreen/AgentDetails/EyeStrength/HBoxContainer/HSlider.min_value
		$ReviewScreen/AgentDetails/HearingDist/HBoxContainer/HSlider.value = $ReviewScreen/AgentDetails/HearingDist/HBoxContainer/HSlider.min_value
		$ReviewScreen/AgentDetails/MovementDist/HBoxContainer/HSlider.value = $ReviewScreen/AgentDetails/MovementDist/HBoxContainer/HSlider.min_value
		$ReviewScreen/AgentDetails/MovementSpeed/HBoxContainer/HSlider.value = $ReviewScreen/AgentDetails/MovementSpeed/HBoxContainer/HSlider.min_value
		for item in range(_review_items_list.item_count):
			_review_items_list.set_item_text(item, "")
		for item in range(_review_weapons_list.item_count):
			_review_weapons_list.set_item_text(item, "")


func reverse_get_index_from_name(icon_name : String):
	for ind in range(_review_items_list.item_count):
		if GameRefs.get_name_from_icon(_review_items_list.get_item_icon(ind)) == icon_name:
			return ind
	for ind in range(_review_weapons_list.item_count):
		if GameRefs.get_name_from_icon(_review_weapons_list.get_item_icon(ind)) == icon_name:
			return ind
	return null


func _on_items_item_selected(index: int) -> void:
	if review_selected_agent == -1:
		return
	var actual_name = GameRefs.get_name_from_icon(_review_items_list.get_item_icon(index))
	if actual_name in agents[review_selected_agent].held_items:
		agents[review_selected_agent].held_items.erase(actual_name)
		_review_items_list.set_item_text(index, "")
	else:
		if len(agents[review_selected_agent].held_items) == 3:
			_review_items_list.deselect(index)
		else:
			agents[review_selected_agent].held_items.append(actual_name)
			_review_items_list.set_item_text(index, "^")


func _on_weapons_item_selected(index: int) -> void:
	if review_selected_agent == -1:
		return
	var actual_name = GameRefs.get_name_from_icon(_review_weapons_list.get_item_icon(index))
	if actual_name in agents[review_selected_agent].held_weapons:
		agents[review_selected_agent].held_weapons.erase(actual_name)
		_review_weapons_list.set_item_text(index, "")
	else:
		if len(agents[review_selected_agent].held_weapons) == 2:
			_review_weapons_list.deselect(index)
		else:
			agents[review_selected_agent].held_weapons.append(actual_name)
			_review_weapons_list.set_item_text(index, "^")


const ADJECTIVE : Array[String] = ["Cunning", "Silent", "White", "Gray", "Black", "Plasma", "Dachous", "Shy", "Cubed", "Smoking", "Large", "Imposing", "Explosive"]
const ANIMAL : Array[String] = ["Wolf", "Bobcat", "Shark", "Serpent", "Penguin", "Crocodile"]

func _on_recruit_agent_pressed() -> void:
	agents.append({
				name=ADJECTIVE.pick_random() + " " + ANIMAL.pick_random() + "_" + str(int(fmod(Time.get_unix_time_from_system(), 1.0) * 100)),
				mission_count=0,
				health=randi_range(5, 10),
				stun_health=randi_range(3, 5),
				view_dist=randf_range(2.00, 2.75),
				view_across=randf_range(0.8, 0.9),
				eye_strength=randf_range(0.30, 0.45),
				hearing_dist=randf_range(0.8, 1.5),
				movement_dist=randf_range(4.0, 6.0),
				movement_speed=randf_range(1.25, 2.7),
				held_items=[],
				held_weapons=[],
			})
	_populate_agent_list()


func _on_fire_agent_pressed() -> void:
	if review_selected_agent > -1:
		agents.remove_at(review_selected_agent)
		review_selected_agent -= 1
	$ReviewScreen/FireAgent.disabled = true
	_populate_agent_list()
	if review_selected_agent > -1:
		_review_agents_list.select(review_selected_agent)
		$ReviewScreen/FireAgent.disabled = false


func _on_save_roster_pressed() -> void:
	save_agents()


func _on_text_change_timer_timeout() -> void:
	$MainMenu/VBoxContainer/HostH/Host.text = "HOST GAME"
	$MainMenu/VBoxContainer/JoinH/Join.text = "JOIN GAME"

