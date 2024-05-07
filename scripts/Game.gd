class_name Game
extends Node3D

var peer = ENetMultiplayerPeer.new()
@export var player_scene : PackedScene

var server_agents : Array[Agent]
var client_agents : Array[Agent]

func _ready():
	# Preconfigure game.
	server_agents = []
	client_agents = []
	pass
	#Lobby.player_loaded.rpc_id(1) # Tell the server that this peer has loaded.


# Called only on the server.
func start_game():
	# All peers are ready to receive RPCs in this scene.

	pass

func create_sound_effect() -> void:
	pass

@rpc()
func ping():
	print("pong!")


func _on_host_pressed() -> void:
	peer.create_server(5040)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_add_player)
	$Menus/MainMenu.visible = false
	$Menus/HostScreen.visible = true
	#_add_player()

func _add_player(id = 1):
	var new_player = player_scene.instantiate()
	new_player.name = str(id)
	call_deferred("add_child", new_player)

@rpc("authority", "call_local", "reliable")
func spawn_agent(player_id):
	pass

func _on_join_pressed() -> void:
	peer.create_client("localhost", 5040)
	multiplayer.multiplayer_peer = peer
	$Menus.visible = false
