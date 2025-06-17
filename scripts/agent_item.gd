class_name AgentItem
extends Resource

@export var name : String
@export var mission_count : int
@export var health : int
@export var stun_health : int
@export var view_dist : float
@export var view_across : float
@export var eye_strength : float
@export var hearing_dist : float
@export var movement_dist : float
@export var movement_speed : float
@export var held_items : Array[String]
@export var held_weapons : Array[String]

func serialize_agent():
	var file = FileAccess.open("user://agents/{0}.mstd".format([name]), FileAccess.WRITE)
	file.store_pascal_string(ProjectSettings.get_setting("application/config/version"))
	file.store_64(mission_count)
	file.store_64(health)
	file.store_64(stun_health)
	file.store_64(view_dist)
	file.store_64(view_across)
	file.store_64(eye_strength)
	file.store_64(hearing_dist)
	file.store_64(movement_dist)
	file.store_64(movement_speed)
	file.store_var(held_items)
	file.store_var(held_weapons)
	file.close()

func load_agent():
	var file = FileAccess.open("user://agents/{0}.mstd".format([name]), FileAccess.READ)
	mission_count = file.get_64()
	health = file.get_64()
	stun_health = file.get_64()
	view_dist = file.get_double()
	view_across = file.get_double()
	eye_strength = file.get_double()
	hearing_dist = file.get_double()
	movement_dist = file.get_double()
	movement_speed = file.get_double()
	held_items = file.get_var()
	held_weapons = file.get_var()
	file.close()
