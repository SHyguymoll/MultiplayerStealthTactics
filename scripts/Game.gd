extends Node3D


var peer = ENetMultiplayerPeer.new()
@export var player_scene : PackedScene

func _ready():
	# Preconfigure game.
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
	$Menus.visible = false
	_add_player()

func _add_player(id = 1):
	var new_player = player_scene.instantiate()
	new_player.name = str(id)
	call_deferred("add_child", new_player)

func _on_join_pressed() -> void:
	peer.create_client("localhost", 5040)
	multiplayer.multiplayer_peer = peer
	$Menus.visible = false
