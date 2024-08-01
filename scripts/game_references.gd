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
		damage = 2,
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
		damage = 2,
		},
	grenade_noise = {
		icon = preload("res://assets/sprites/hud_agent_small/weapons/noise_maker.png"),
		name = "Audio Grenade",
		type = WeaponTypes.THROWN,
		cooldown_time = 30,
		reload_time = 10,
		ammo = 1,
		damage = 0,
		},
	flag_center = {
		icon = preload("res://assets/sprites/hud_agent_small/weapons/flag.png"),
		name = "Flag",
		type = WeaponTypes.CQC,
		cooldown_time = 5,
		reload_time = 0,
		ammo = 1,
		damage = 0,
		},
	flag_server = {
		icon = preload("res://assets/sprites/hud_agent_small/weapons/flag.png"),
		name = "Enemy Flag",
		type = WeaponTypes.CQC,
		cooldown_time = 5,
		reload_time = 0,
		ammo = 1,
		damage = 0,
		},
	flag_client = {
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
	no_item = {
		icon = preload("res://assets/sprites/hud_agent_small/items/no_item.png"),
		name = "null"
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

const TXT := {
	of_intro = "LOCATE AND EXFILTRATE THE FLAG",
	of_y_get = "YOU HAVE THE FLAG",
	of_t_get = "THEY HAVE THE FLAG",
	of_y_lost = "YOU LOST THE FLAG",
	of_t_lost = "THEY LOST THE FLAG",
	of_cap_agents_remain = "THE FLAG HAS BEEN CAPTURED, AGENTS STILL REMAIN",
	of_y_cap_left = "THE FLAG HAS BEEN CAPTURED, ALL AGENTS LEFT HOT ZONE, MISSION SUCCESS",
	of_t_cap_left = "THE FLAG HAS BEEN CAPTURED, OTHER TEAM LEFT HOT ZONE, MISSION FAILURE",
	tf_intro = "LOCATE AND EXFILTRATE THE ENEMY'S FLAG",
	tf_y_get = "YOU HAVE THE ENEMY FLAG",
	tf_t_get = "THE ENEMY HAS YOUR FLAG",
	tf_y_lost = "YOU LOST THE ENEMY FLAG",
	tf_t_lost = "THE ENEMY LOST YOUR FLAG",
	tf_y_cap_agents_remain = "YOU CAPTURED THE ENEMY FLAG, EXFILTRATE REMAINING AGENTS",
	tf_t_cap_agents_remain = "ENEMY TEAM CAPTURED YOUR FLAG, NEUTRALIZE REMAINING AGENTS",
	tf_y_cap_left = "YOU CAPTURED THE ENEMY FLAG, ALL AGENTS LEFT HOT ZONE, MISSION SUCCESS",
	tf_t_cap_left = "ENEMY TEAM CAPTURED YOUR FLAG, OTHER TEAM FULLY EXFILTRATED, MISSION FAILURE",
	mission_success = "ALL AGENTS LEFT HOT ZONE, MISSION SUCCESS",
	mission_failure = "OTHER TEAM LEFT HOT ZONE, MISSION FAILURE",

	any_t_dead = "ALL ENEMY COMBATANTS NEUTRALIZED, MISSION SUCCESS",
	any_a_dead = "ALL OPERATIVES KIA, MISSION DRAW",
	any_y_dead = "TEAM IS KIA, MISSION FAILURE",
}

const AUDIO = {
	ag_step_quiet = preload("res://assets/sounds/agent/footfall_slow.wav"),
	ag_step_loud = preload("res://assets/sounds/agent/footfall_fast.wav"),
	ag_hurt = preload("res://assets/sounds/agent/hurt.wav"),
	ag_die = preload("res://assets/sounds/agent/die.wav"),
	ag_saw_something = preload("res://assets/sounds/agent/noticed_sight.wav"),
	ag_detect_element = preload("res://assets/sounds/agent/detected_element.wav"),
	ag_detect_agent = preload("res://assets/sounds/agent/detected_agent.wav"),
	ag_exfil = preload("res://assets/sounds/agent/exfiltrated.wav"),

	pistol = preload("res://assets/sounds/weapon/pistol.wav"),
	rifle = preload("res://assets/sounds/weapon/rifle.wav"),
	shotgun = preload("res://assets/sounds/weapon/shotgun.wav"),
	grenade_bounce = preload("res://assets/sounds/weapon/grenade_bounce.wav"),
	grenade_frag = preload("res://assets/sounds/weapon/grenade_frag.wav"),
	grenade_smoke = preload("res://assets/sounds/weapon/grenade_smoke.wav"),
	projectile_bounce = preload("res://assets/sounds/weapon/projectile_bounce.wav"),
}

func get_weapon_attribute(weapon : GameWeapon, attribute : String):
	if weapon == null:
		return null
	return WEP[weapon.wep_id].get(attribute, null)


func get_held_weapon_attribute(agent : Agent, weapon_ind : int, attribute : String):
	return get_weapon_attribute(get_weapon_node(agent.held_weapons[weapon_ind]), attribute)


func get_pickup_attribute(pickup : WeaponPickup, attribute : String):
	return get_weapon_attribute(get_weapon_node(pickup.attached_wep), attribute)


func compare_wep_type(agent : Agent, wep_type : WeaponTypes):
	return get_held_weapon_attribute(agent, agent.selected_weapon, "type") == wep_type


func get_all_wep_and_itm_icons():
	var icons = []
	for itm in ITM:
		icons.append(ITM[itm].icon)
	for wep in WEP:
		icons.append(WEP[wep].icon)
	return icons


func get_weapon_node(weapon_name : String) -> GameWeapon:
	return $"/root/Game/Weapons".get_node_or_null(weapon_name)


func get_pickup_node(pickup_name : String) -> WeaponPickup:
	return $"/root/Game/Pickups".get_node_or_null(pickup_name)


func return_icon(agent : Agent, is_wep : bool):
	if is_wep:
		if get_held_weapon_attribute(agent, agent.selected_weapon, "icon") == null:
			return ITM.none.icon
		return get_held_weapon_attribute(agent, agent.selected_weapon, "icon")
	else:
		if agent.selected_item == -1:
			return ITM.none.icon
		return ITM.get(agent.held_items[agent.selected_item]).icon


func get_name_from_icon(icon : Texture2D):
	for check in ITM:
		if ITM[check].icon == icon:
			return check
	for check in WEP:
		if WEP[check].icon == icon:
			return check
	return null


func extract_agent_name(agent_name : String):
	return agent_name.split("_")[1]
