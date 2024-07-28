class_name Grenade
extends CharacterBody3D

@export var server_knows : bool
@export var client_knows : bool

@export var boom_time : int

var landing_position : Vector3

var wep_id : String

func _ready() -> void:
	get_node(wep_id).visible = true

func _tick() -> void:
	boom_time = max(boom_time - 1, 0)

