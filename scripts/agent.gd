extends Node2D

var view_dist : int
var view_width_step : int
var view_direction : int
var eye_strength : int

var hearing_radius : int

var movement_dist : int

var camo_level : int

var held_items : Array[GameItem]
var held_weapons : Array[GameWeapon]

var selected_item : int
var selected_weapon : int

func select_item
