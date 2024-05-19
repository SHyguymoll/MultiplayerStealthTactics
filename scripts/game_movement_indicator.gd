extends AnimatedSprite3D

var referenced_agent : Agent

func _ready() -> void:
	match referenced_agent.queued_action[1]:
		Agent.GameActions.WALK_TO_POS:
			pass
		Agent.GameActions.RUN_TO_POS:
			pass
		Agent.GameActions.CROUCH_WALK_TO_POS:
			pass
		Agent.GameActions.CRAWL_TO_POS:
			pass

func _game_step(delta):
	if referenced_agent.queued_action[1] not in [Agent.GameActions.WALK_TO_POS, Agent.GameActions.RUN_TO_POS, Agent.GameActions.CROUCH_WALK_TO_POS, Agent.GameActions.CRAWL_TO_POS]:
		if referenced_agent.queued_action[1] == Agent.GameActions.HALT:
			pass
		else:
			pass

func _on_animation_changed() -> void:
	await animation_finished
	queue_free()
