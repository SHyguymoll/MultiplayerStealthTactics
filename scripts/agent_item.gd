class_name AgentItem
extends Resource

## The name of the agent.
@export var name : String
## The number of missions that this agent has succeeded at and survived.
@export var mission_count : int
## The life force of the agent. This value is strictly between 1 and 4 health points, inclusive.
@export var health : int
## The energy of the agent. This value is strictly between 3 and 8 stun health points, inclusive.
@export var stun_health : int
## How far the agent can see, between 2.00 and 3.50 meters.
@export var view_dist : float
## The peripheral vision of the agent, between 0.80 and 1.20 meters.
@export var view_across : float
## The visual acuity of the agent when an element/agent is within its sights, between 0.30 and 0.60.[br]
## This value acts as an exponent when calculating sight chances. The formula is included [here](https://www.desmos.com/calculator/azk19m9ik3)
@export var eye_strength : float
## The radius of sounds the agent can pick up, between 0.80 and 1.65 meters.
@export var hearing_dist : float
## How far the agent can move in a single turn, between 4.00 and 9.00 meters.
@export var movement_dist : float
## How fast the agent moves in a single turn, between 1.25 and 3.00 meters/tick.
@export var movement_speed : float
## The items held by the agent. Maxes out at 2.
@export var held_items : Array[String]
## The weapons equipped by the agent. Maxes out at 2.
@export var held_weapons : Array[String]

func serialize_agent():
	var file = FileAccess.open("user://agents/{0}.mstd".format([name]), FileAccess.WRITE)
	file.store_pascal_string(ProjectSettings.get_setting("application/config/version"))
	file.store_pascal_string(name)
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


func load_agent(file_string : String):
	var file = FileAccess.open(file_string, FileAccess.READ)
	var version = file.get_pascal_string()
	name = file.get_pascal_string()
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
