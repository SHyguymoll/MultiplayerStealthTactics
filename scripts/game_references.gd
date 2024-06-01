extends Node

const WEP := {
	fist = {
		icon = preload("res://assets/sprites/hud_agent_small/weapons/fist.png"),
		name = "Hand to Hand",
		},
	pistol = {
		icon = preload("res://assets/sprites/hud_agent_small/weapons/pistol.png"),
		name = "Sidearm",
		},
	rifle = {
		icon = preload("res://assets/sprites/hud_agent_small/weapons/rifle.png"),
		name = "Rifle",
		},
	shotgun = {
		icon = preload("res://assets/sprites/hud_agent_small/weapons/shotgun.png"),
		name = "Shotgun",
		},
	grenade_smoke = {
		icon = preload("res://assets/sprites/hud_agent_small/weapons/grenade_smoke.png"),
		name = "Smoke Grenade",
		},
	grenade_frag = {
		icon = preload("res://assets/sprites/hud_agent_small/weapons/grenade_frag.png"),
		name = "Fragmentation Grenade",
		},
	noise_maker = {
		icon = preload("res://assets/sprites/hud_agent_small/weapons/noise_maker.png"),
		name = "Audio Disturber",
		},
	middle_flag = {
		icon = preload("res://assets/sprites/hud_agent_small/weapons/flag.png"),
		name = "Flag",
		},
	enemy_flag = {
		icon = preload("res://assets/sprites/hud_agent_small/weapons/flag.png"),
		name = "Enemy Flag",
		},
}

const ITM := {
	none = {
		icon = preload("res://assets/sprites/hud_agent_small/items/none.png"),
		name = "Nothing",
		},
	body_armor = {
		icon = preload("res://assets/sprites/hud_agent_small/items/body_armor.png"),
		name = "Body Armor",
		},
	fake_death = {
		icon = preload("res://assets/sprites/hud_agent_small/items/fake_death_pill.png"),
		name = "False Death Pill",
		},
	box = {
		icon = preload("res://assets/sprites/hud_agent_small/items/box.png"),
		name = "Cardboard Box",
		},
	cigar = {
		icon = preload("res://assets/sprites/hud_agent_small/items/cigar.png"),
		name = "Cigar",
		},
	reflex_enhancer = {
		icon = preload("res://assets/sprites/hud_agent_small/items/reflex_pill.png"),
		name = "Reflex Pill",
		},
	analyzer = {
		icon = preload("res://assets/sprites/hud_agent_small/items/analyzer.png"),
		name = "Kit Analyzer",
		},
}

const STE := {
	active = preload("res://assets/sprites/hud_agent_small/state/active.png"),
	alert = preload("res://assets/sprites/hud_agent_small/state/alert.png"),
	stunned = preload("res://assets/sprites/hud_agent_small/state/stunned.png"),
	asleep = preload("res://assets/sprites/hud_agent_small/state/asleep.png"),
	dead = preload("res://assets/sprites/hud_agent_small/state/dead.png"),
	unknown = preload("res://assets/sprites/hud_agent_small/state/unknown.png"),
}
