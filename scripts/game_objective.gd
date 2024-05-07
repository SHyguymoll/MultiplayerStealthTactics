class_name GameObjective
extends Node3D

signal server_agent_activated_objective(agent : Agent)
signal server_agent_lost_objective(agent : Agent)
signal client_agent_activated_objective(agent : Agent)
signal client_agent_lost_objective(agent : Agent)

func game_use(agent : Agent):
	pass
