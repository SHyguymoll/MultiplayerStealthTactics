class_name AgentAnimationTree
extends AnimationTree

@export var weapons_animation_blend := Vector2.ONE

@onready var agent : Agent = $".."
@onready var _anim_state : AnimationNodeStateMachinePlayback = get("parameters/playback")


func _ready() -> void:
	_anim_state.start("Stand")
	advance(0)


func _physics_process(delta: float) -> void:
	pass


@rpc("authority", "call_local", "reliable")
func _game_step(delta: float):
	if len(agent.queued_action) > 0 and agent.queued_action[0] != Agent.GameActions.RELOAD_WEAPON:
		weapons_animation_blend = weapons_animation_blend.lerp(decide_weapon_blend(), Agent.GENERAL_LERP_VAL)

	set("parameters/Crouch/blend_position", weapons_animation_blend)
	set("parameters/Stand/blend_position", weapons_animation_blend)
	advance(delta)

	if len(agent.queued_action) < 2:
		match agent.state:
			Agent.States.WALK, Agent.States.RUN:
				_anim_state.travel("Stand")
			Agent.States.CROUCH_WALK:
				_anim_state.travel("Crouch")
			Agent.States.CRAWL:
				_anim_state.travel("B_Prone")
		return
	if agent.position.distance_to(agent.queued_action[1]) < 0.3 or agent.game_steps_since_execute > 10*60:
		match agent.state:
			Agent.States.WALK, Agent.States.RUN:
				_anim_state.travel("Stand")
			Agent.States.CROUCH_WALK:
				_anim_state.travel("Crouch")
			Agent.States.CRAWL:
				_anim_state.travel("B_Prone")
		return
	if agent.state == Agent.States.STUNNED and agent.stun_time == 0:
		_anim_state.travel("Crouch")
	if agent.queued_action[0] == Agent.GameActions.USE_WEAPON and agent.attack_step == Agent.AttackStep.ATTACKING:
		var wep_type = GameRefs.WEP[GameRefs.get_weapon_node(agent.held_weapons[agent.selected_weapon]).wep_id].type
		if wep_type == GameRefs.WeaponTypes.PLACED and agent.game_steps_since_execute == 20:
			_anim_state.travel("Stand")


func decide_weapon_blend() -> Vector2:
	match GameRefs.get_held_weapon_attribute(agent, agent.selected_weapon, "type"):
		GameRefs.WeaponTypes.CQC:
			return Vector2.ONE
		GameRefs.WeaponTypes.SMALL:
			return Vector2.LEFT + Vector2.DOWN
		GameRefs.WeaponTypes.BIG:
			return Vector2.ONE * -1
		_:
			return Vector2.RIGHT + Vector2.UP


func _attack_orient_transition(attack_type : GameRefs.WeaponTypes):
	if is_animating("Stand"):
		match attack_type:
			GameRefs.WeaponTypes.SMALL:
				_anim_state.travel("B_Stand_Attack_SmallArms")
			GameRefs.WeaponTypes.BIG:
				_anim_state.travel("B_Stand_Attack_BigArms")
			GameRefs.WeaponTypes.THROWN:
				_anim_state.travel("B_Stand_Attack_Grenade")
			GameRefs.WeaponTypes.PLACED:
				_anim_state.travel("Crouch")
	elif is_animating("Crouch"):
		match attack_type:
			GameRefs.WeaponTypes.SMALL:
				_anim_state.travel("B_Crouch_Attack_SmallArms")
			GameRefs.WeaponTypes.BIG:
				_anim_state.travel("B_Crouch_Attack_BigArms")
			GameRefs.WeaponTypes.THROWN:
				_anim_state.travel("B_Crouch_Attack_Grenade")
			GameRefs.WeaponTypes.PLACED:
				pass


func is_animating(anim_string : String):
	return _anim_state.get_current_node() == anim_string


func select_stun_animation(positive_stun_health : bool):
	_anim_state.travel("B_Hurt_Slammed" if positive_stun_health else "B_Hurt_Collapse")


func select_hurt_animation():
	if agent.health == 0:
		_anim_state.travel("B_Hurt_Collapse")
		return
	var cur_node = _anim_state.get_current_node()
	if cur_node.begins_with("B_Stand_") or cur_node in ["B_Walk", "B_Run", "B_CrouchToStand", "B_Hurt_Standing", "Stand"]:
		_anim_state.travel("B_Hurt_Standing")
	elif cur_node.begins_with("B_Crouch_") or cur_node in ["B_ProneToCrouch", "B_StandToCrouch", "Crouch", "B_Crouch_Walk"]:
		_anim_state.travel("B_Hurt_Crouching")
	else:
		_anim_state.travel("B_Hurt_Prone")

func update_animation_action(action: Agent.GameActions):
	match action:
		Agent.GameActions.GO_STAND:
			_anim_state.travel("Stand")
		Agent.GameActions.GO_CROUCH:
			_anim_state.travel("Crouch")
		Agent.GameActions.GO_PRONE:
			_anim_state.travel("B_Prone")
		Agent.GameActions.RUN_TO_POS:
			_anim_state.travel("B_Run")
		Agent.GameActions.WALK_TO_POS:
			_anim_state.travel("B_Walk")
		Agent.GameActions.CROUCH_WALK_TO_POS:
			_anim_state.travel("B_Crouch_Walk")
		Agent.GameActions.CRAWL_TO_POS:
			_anim_state.travel("B_Crawl")
		Agent.GameActions.PICK_UP_WEAPON:
			if agent.in_standing_state():
				_anim_state.travel("Stand")
			elif agent.in_crouching_state():
				_anim_state.travel("Crouch")
		Agent.GameActions.DROP_WEAPON:
			if agent.in_standing_state():
				_anim_state.travel("Stand")
			elif agent.in_crouching_state():
				_anim_state.travel("Crouch")
		Agent.GameActions.USE_WEAPON:
			if agent.in_standing_state():
				_anim_state.travel("Stand")
			elif agent.in_crouching_state():
				_anim_state.travel("Crouch")
		Agent.GameActions.HALT:
			if agent.state in [Agent.States.RUN, Agent.States.WALK]:
				_anim_state.travel("Stand")
			if agent.state == Agent.States.CROUCH_WALK:
				_anim_state.travel("Crouch")
			if agent.state == Agent.States.CRAWL:
				_anim_state.travel("B_Prone")


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "B_Hurt_Collapse":
		if agent.health == 0:
			_anim_state.travel("B_Dead")
		if agent.stun_health == 0:
			_anim_state.travel("B_Hurt_Stunned")
