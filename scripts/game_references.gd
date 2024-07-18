extends Node

enum WeaponTypes {
	CQC,
	SMALL,
	BIG,
	THROWN,
	PLACED,
}
const WEP := {
	fist = {
		icon = preload("res://assets/sprites/hud_agent_small/weapons/fist.png"),
		name = "Hand to Hand",
		type = WeaponTypes.CQC,
		cooldown_time = 5,
		reload_time = 0,
		ammo = 1,
		damage = 0,
		},
	pistol = {
		icon = preload("res://assets/sprites/hud_agent_small/weapons/pistol.png"),
		name = "Sidearm",
		type = WeaponTypes.SMALL,
		cooldown_time = 30,
		reload_time = 75,
		ammo = 9,
		damage = 1,
		},
	rifle = {
		icon = preload("res://assets/sprites/hud_agent_small/weapons/rifle.png"),
		name = "Rifle",
		type = WeaponTypes.BIG,
		cooldown_time = 7,
		reload_time = 170,
		ammo = 15,
		damage = 2,
		},
	shotgun = {
		icon = preload("res://assets/sprites/hud_agent_small/weapons/shotgun.png"),
		name = "Shotgun",
		type = WeaponTypes.BIG,
		cooldown_time = 40,
		reload_time = 250,
		ammo = 6,
		damage = 5,
		},
	grenade_smoke = {
		icon = preload("res://assets/sprites/hud_agent_small/weapons/grenade_smoke.png"),
		name = "Smoke Grenade",
		type = WeaponTypes.THROWN,
		cooldown_time = 30,
		reload_time = 5,
		ammo = 1,
		damage = 0,
		},
	grenade_frag = {
		icon = preload("res://assets/sprites/hud_agent_small/weapons/grenade_frag.png"),
		name = "Fragmentation Grenade",
		type = WeaponTypes.THROWN,
		cooldown_time = 30,
		reload_time = 5,
		ammo = 1,
		damage = 4,
		},
	noise_maker = {
		icon = preload("res://assets/sprites/hud_agent_small/weapons/noise_maker.png"),
		name = "Audio Disturber",
		type = WeaponTypes.THROWN,
		cooldown_time = 30,
		reload_time = 10,
		ammo = 1,
		damage = 0,
		},
	middle_flag = {
		icon = preload("res://assets/sprites/hud_agent_small/weapons/flag.png"),
		name = "Flag",
		type = WeaponTypes.CQC,
		cooldown_time = 5,
		reload_time = 0,
		ammo = 1,
		damage = 0,
		},
	enemy_flag = {
		icon = preload("res://assets/sprites/hud_agent_small/weapons/flag.png"),
		name = "Enemy Flag",
		type = WeaponTypes.CQC,
		cooldown_time = 5,
		reload_time = 0,
		ammo = 1,
		damage = 0,
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

const POPUP := {
	sight_unknown = preload("res://assets/sprites/game_popups/unknown_sight.png"),
	sound_unknown = preload("res://assets/sprites/game_popups/unknown_sound.png"),
	spotted = preload("res://assets/sprites/game_popups/spotted.png"),
}

func compare_wep_type(agent : Agent, wep_type : WeaponTypes):
	return WEP[agent.held_weapons[agent.selected_weapon].wep_name].type == wep_type

func return_icon(agent : Agent, is_wep : bool):
	if is_wep:
		if WEP.get(agent.held_weapons[agent.selected_weapon].wep_name, null) == null:
			return ITM.none.icon
		return WEP.get(agent.held_weapons[agent.selected_weapon].wep_name).icon
	else:
		return ITM.get(agent.held_items[agent.selected_item]).icon
