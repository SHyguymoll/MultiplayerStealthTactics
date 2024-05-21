extends AnimatedSprite3D

signal indicator_placed(indicator)
const CLOSENESS := 2.0

var referenced_agent : Agent
var ind_set := false

var flat_position : Vector2

func _ready() -> void:
	match referenced_agent.queued_action[1]:
		Agent.GameActions.WALK_TO_POS:
			play("walk")
		Agent.GameActions.RUN_TO_POS:
			play("run")
		Agent.GameActions.CROUCH_WALK_TO_POS:
			play("crouch_walk")
		Agent.GameActions.CRAWL_TO_POS:
			play("crawl")


func _game_step(delta):
	if referenced_agent.queued_action[1] == Agent.GameActions.HALT and referenced_agent.position.distance_to(position) <= CLOSENESS:
		play("movement_end_success")
		return
	else:
		play("movement_end_neutral")
		return
	if referenced_agent.in_incapacitated_state():
		play("movement_end_fail")
		return

func _on_animation_changed() -> void:
	if not ind_set:
		return
	await animation_finished
	queue_free()

func _process(delta: float) -> void:
	if not ind_set:
		flat_position = get_viewport().get_mouse_position()
		position = Vector3(flat_position.x, 10, flat_position.y)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not ind_set:
			ind_set = true
			indicator_placed.emit(self)
