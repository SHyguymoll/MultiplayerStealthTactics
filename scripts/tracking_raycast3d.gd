extends RayCast3D

var source : Node3D
var sink : Node3D

func _physics_process(_d: float) -> void:
	global_position = source.global_position
	target_position = sink.global_position - source.global_position

# put this in Game.gd uncommented to enable it
#@rpc("authority", "call_local", "reliable")
#func create_all_raycasts():
	#for agent_block in server_agents.keys():
		#var agent = server_agents[agent_block]["agent_node"]
		#for cli_agent_block in client_agents.keys():
			#var cli_agent = client_agents[cli_agent_block]["agent_node"]
			#var new_tracking_ray = tracking_raycast3d_scene.instantiate()
			#new_tracking_ray.source = agent
			#new_tracking_ray.sink = cli_agent
			#new_tracking_ray.name = agent.name + "|" + cli_agent.name
			#$RayCasts.add_child(new_tracking_ray)
			#print("created ray ", new_tracking_ray)
