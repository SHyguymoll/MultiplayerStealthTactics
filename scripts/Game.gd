extends Node3D


func _ready():
	# Preconfigure game.

	Lobby.player_loaded.rpc_id(1) # Tell the server that this peer has loaded.


# Called only on the server.
func start_game():
	# All peers are ready to receive RPCs in this scene.
	pass

func create_sound_effect() -> void:
	pass
