extends Node3D

@onready var agent : Agent = $Agent
@onready var debug_label : Label3D = $DebugLabel3D

func _ready() -> void:
	# states
	$DebugValues/DuringGame/State/Scroll.min_value = 0
	$DebugValues/DuringGame/State/Scroll.max_value = len(agent.States.keys()) - 1
	$DebugValues/DuringGame/State/Scroll.value = 0
	$DebugValues/DuringGame/State/Scroll.step = 1
	# eyes
	$DebugValues/DuringGame/Eye/Scroll.min_value = 0.05
	$DebugValues/DuringGame/Eye/Scroll.max_value = 1
	$DebugValues/DuringGame/Eye/Scroll.value = 1
	$DebugValues/GameSetup/EyeLengthScroll.min_value = 0.5
	$DebugValues/GameSetup/EyeLengthScroll.max_value = 4.5
	$DebugValues/GameSetup/EyeLengthScroll.value = 2.5
	$DebugValues/GameSetup/EyeAcrossScroll.min_value = 0.5
	$DebugValues/GameSetup/EyeAcrossScroll.max_value = 1.5
	$DebugValues/GameSetup/EyeAcrossScroll.value = 1
	# ears
	$DebugValues/DuringGame/Ear/Scroll.min_value = 0
	$DebugValues/DuringGame/Ear/Scroll.max_value = 1
	$DebugValues/DuringGame/Ear/Scroll.value = 1
	$DebugValues/GameSetup/EarScroll.min_value = 0.25
	$DebugValues/GameSetup/EarScroll.max_value = 3
	$DebugValues/GameSetup/EarScroll.value = 1.5
	# head rotation
	$DebugValues/DuringGame/Head/Scroll.min_value = -(PI * 0.9)/2
	$DebugValues/DuringGame/Head/Scroll.max_value = (PI * 0.9)/2
	$DebugValues/DuringGame/Head/Scroll.value = 0
	$DebugValues/DuringGame/Head/Scroll.step = 0.01
	# show debug shapes


func _physics_process(d: float) -> void:
	agent.state = $DebugValues/DuringGame/State/Scroll.value
	agent.view_dist = $DebugValues/GameSetup/EyeLengthScroll.value
	agent.view_across = $DebugValues/GameSetup/EyeAcrossScroll.value
	agent.hearing_dist = $DebugValues/GameSetup/EarScroll.value
	agent.eye_strength = $DebugValues/DuringGame/Eye/Scroll.value
	agent._game_step(d, true)
	debug_label.text = str(agent.target_visible_level) + "\n" + str(agent.noticed)

func _process(_d : float) -> void:
	$DebugValues/DuringGame/State/Label.text = agent.States.keys()[agent.state]
	$DebugCamera.position = lerp(
			Vector3(1.56, 0.553, 0.802),
			Vector3(0.969, 3.016, 0.634),
			$DebugValues/CameraScroll.value)
	$DebugCamera.rotation_degrees = lerp(
			Vector3(0, 61.3, 0),
			Vector3(-74.9, 61.3, 0.629),
			$DebugValues/CameraScroll.value)
