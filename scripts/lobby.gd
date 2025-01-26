extends Node

# Autoload named Lobby

# These signals can be connected to by a UI lobby scene or the game scene.
signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected

# Server details
const DEFAULT_SERVER_IP = "127.0.0.1" # IPv4 localhost
const PORT_MIN = 6780
const PORT_MAX = 9999
const MAX_CONNECTIONS = 2

var upnp : UPNP
var port : int = 6780
var port_known : bool
var extern_addr : String
var lan_mode : bool

# Game details
# This will contain player info for every player,
# with the keys being each player's unique IDs.
var players = {}

# This is the local player info. This should be modified locally
# before the connection is made. It will be passed to every other peer.
# For example, the value of "name" can be set to something the player
# entered in a UI scene.
var player_info = {}

var players_loaded = 0

func _ready():
	# When a peer connects, send them my player info.
	# This allows transfer of all desired data for each player, not only the unique ID.
	multiplayer.peer_connected.connect(func(id):
		_register_player.rpc_id(id, player_info))

	multiplayer.peer_disconnected.connect(func(id):
		players.erase(id)
		player_disconnected.emit(id))

	multiplayer.connected_to_server.connect(func():
		var peer_id = multiplayer.get_unique_id()
		players[peer_id] = player_info
		player_connected.emit(peer_id, player_info))

	multiplayer.connection_failed.connect(func():
		multiplayer.multiplayer_peer = null)

	multiplayer.server_disconnected.connect(func():
		multiplayer.multiplayer_peer = null
		players.clear()
		server_disconnected.emit())


func join_game(address = "") -> int:
	if address.is_empty():
		return ERR_UNCONFIGURED
	var peer = ENetMultiplayerPeer.new()
	port = int(address.split(":")[1])
	address = address.split(":")[0]
	var error = peer.create_client(address, port)
	if error:
		return error
	multiplayer.multiplayer_peer = peer
	return 0


func create_upnp_thing():
	upnp = UPNP.new()
	if upnp.discover() == UPNP.UPNP_RESULT_SUCCESS:
		if upnp.get_gateway() and upnp.get_gateway().is_valid_gateway():
			var res_udp = upnp.add_port_mapping(port, 0, "godot_multiplayerstealthtactics", "UDP")
			var res_tcp = upnp.add_port_mapping(port, 0, "godot_multiplayerstealthtactics", "TCP")
			if not res_udp == UPNP.UPNP_RESULT_SUCCESS:
				upnp.add_port_mapping(port, 0, "", "UDP")
			if not res_tcp == UPNP.UPNP_RESULT_SUCCESS:
				upnp.add_port_mapping(port, 0, "", "TCP")
	extern_addr = upnp.query_external_address()

func destroy_upnp_thing():
	if lan_mode: #there is no upnp in lan world, networks make sense here
		return
	upnp.delete_port_mapping(port, "UDP")
	upnp.delete_port_mapping(port, "TCP")

func create_game(max_connections = 0, is_lan = false):
	port = port if port_known else randi_range(PORT_MIN, PORT_MAX)
	lan_mode = is_lan
	if lan_mode:
		extern_addr = DEFAULT_SERVER_IP + ":" + str(port)
	else: # internet game, UPNP is a stopgap until something a little less crap can be used
		create_upnp_thing()
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, MAX_CONNECTIONS)
	if error:
		return error
	multiplayer.multiplayer_peer = peer
	players[1] = player_info
	player_connected.emit(1, player_info)


func remove_multiplayer_peer():
	multiplayer.multiplayer_peer = null


# When the server decides to start the game from a UI scene,
# do Lobby.load_game.rpc(filepath)
@rpc("call_local", "reliable")
func load_game(game_scene_path):
	get_tree().change_scene_to_file(game_scene_path)


# Every peer will call this when they have loaded the game scene.
@rpc("any_peer", "call_local", "reliable")
func player_loaded():
	if multiplayer.is_server():
		players_loaded += 1
		if players_loaded == players.size():
			$/root/Game.start_game()
			players_loaded = 0


@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = new_player_info
	player_connected.emit(new_player_id, new_player_info)
