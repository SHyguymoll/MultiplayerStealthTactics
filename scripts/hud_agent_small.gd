class_name HUDAgentSmall
extends Control
var state := {
	active = preload("res://assets/sprites/hud_agent_small/state/active.png"),
	stunned = preload("res://assets/sprites/hud_agent_small/state/stunned.png"),
	asleep = preload("res://assets/sprites/hud_agent_small/state/asleep.png"),
	dead = preload("res://assets/sprites/hud_agent_small/state/dead.png"),
	unknown = preload("res://assets/sprites/hud_agent_small/state/unknown.png"),
}

var weapon := {
	fist = preload("res://assets/sprites/hud_agent_small/weapons/fist.png"),
	pistol = preload("res://assets/sprites/hud_agent_small/weapons/pistol.png"),
	rifle = preload("res://assets/sprites/hud_agent_small/weapons/rifle.png"),
	shotgun = preload("res://assets/sprites/hud_agent_small/weapons/shotgun.png"),
	grenade_smoke = preload("res://assets/sprites/hud_agent_small/weapons/grenade_smoke.png"),
	grenade_frag = preload("res://assets/sprites/hud_agent_small/weapons/grenade_frag.png"),
	noise_maker = preload("res://assets/sprites/hud_agent_small/weapons/noise_maker.png"),
	middle_flag = preload("res://assets/sprites/hud_agent_small/weapons/flag.png"),
	enemy_flag = preload("res://assets/sprites/hud_agent_small/weapons/flag.png"),
}

var item := {
	none = preload("res://assets/sprites/hud_agent_small/items/none.png"),
	body_armor = preload("res://assets/sprites/hud_agent_small/items/body_armor.png"),
	fake_death = preload("res://assets/sprites/hud_agent_small/items/fake_death_pill.png"),
	box = preload("res://assets/sprites/hud_agent_small/items/box.png"),
	cigar = preload("res://assets/sprites/hud_agent_small/items/cigar.png"),
	reflex_enhancer = preload("res://assets/sprites/hud_agent_small/items/reflex_pill.png"),
	analyzer = preload("res://assets/sprites/hud_agent_small/items/analyzer.png"),
}


func update_state(new_state):
	($Textures/AgentState as TextureRect).texture = state.get(new_state, state.unknown)


func update_weapon(new_weapon):
	($Textures/Equipped/Weapon as TextureRect).texture = weapon.get(new_weapon, weapon.fist)


func update_item(new_item):
	($Textures/Equipped/Item as TextureRect).texture = item.get(new_item, item.none)
