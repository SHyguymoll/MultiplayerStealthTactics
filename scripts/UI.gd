class_name UI
extends Node2D

@onready var quick_views : HBoxContainer = $HUDBase/QuickViews
@onready var radial_menu = $HUDSelected/RadialMenu
@onready var execute_button : Button = $HUDBase/Execute
@onready var phase_label : Label = $HUDBase/CurrentPhase
@onready var ag_insts : Label = $HUDBase/AgentInstructions
@onready var hurry_up : Label = $HUDBase/HurryUp

@onready var fadeout_base = $FadeOut
@onready var fadeout_rect = $FadeOut/ColorRect

@onready var serv_name : Label = $HUDBase/ServerPlayerName
@onready var clie_name : Label = $HUDBase/ClientPlayerName
@onready var serv_prog : ProgressBar = $HUDBase/ProgressBarServer
@onready var clie_prog : ProgressBar = $HUDBase/ProgressBarClient

@onready var toasts : VBoxContainer = $HUDToasts/Toasts

@onready var round_update : AudioStreamPlayer = $SoundEffects/RoundUpdate
@onready var round_ended : AudioStreamPlayer = $SoundEffects/RoundEnded
@onready var actions_submitted : AudioStreamPlayer = $SoundEffects/ActionsSubmitted

@onready var music_progress : AudioStreamPlayer = $Music/InProgress
@onready var music_victory : AudioStreamPlayer = $Music/Victory
@onready var music_failure : AudioStreamPlayer = $Music/Failure

@onready var gameover_anim : AnimatedSprite2D = $FadeOut/ColorRect/AnimatedSprite2D

@onready var selectors : CanvasLayer = $HUDSelectors

@onready var pause_menu : CanvasLayer = $PauseMenu
@onready var pause_menu_yes : Button = $PauseMenu/ColorRect/VBoxContainer/YesForfeit
@onready var pause_menu_no : Button = $PauseMenu/ColorRect/VBoxContainer/NoForfeit
@onready var pause_menu_phase : Label = $PauseMenu/ColorRect/CurrentPhase

var hud_agent_small_scene = preload("res://scenes/hud_agent_small.tscn")
var popup_scene = preload("res://scenes/game_popup.tscn")
var audio_event_scene = preload("res://scenes/game_audio_event.tscn")
var toast_scene = preload("res://scenes/toast.tscn")
var agent_selector_scene = preload("res://scenes/agent_selector.tscn")

@onready var server = $"../MultiplayerHandler"
@onready var game = $".."

func _ready() -> void:
	fadeout_base.visible = true
	fadeout_rect.modulate = Color.WHITE
	hurry_up.visible = false
	radial_menu.visible = false
	close_pause_menu()


func _physics_process(delta: float) -> void:
	serv_prog.value = lerpf(serv_prog.value, float(server.server_progress), 0.2)
	clie_prog.value = lerpf(clie_prog.value, float(server.client_progress), 0.2)


func _process(_d: float) -> void:
	if Input.is_action_just_pressed("pause_menu"):
		open_pause_menu()


func animate_fade(in_out := true):
	var twe := create_tween()
	if in_out:
		twe.tween_property(fadeout_rect, "modulate", Color.WHITE, 1.5).from(Color.TRANSPARENT)
	else:
		twe.tween_property(fadeout_rect, "modulate", Color.TRANSPARENT, 1.5).from(Color.WHITE)

func create_toast(text : String, add_sound_effect : bool, color := Color(0.565, 0, 0.565, 0.212)):
	var new_toast : ToastMessage = toast_scene.instantiate()
	new_toast.input_text = text
	new_toast.color = color
	toasts.add_child(new_toast)
	if add_sound_effect:
		round_update.play()
		pass
	pass


func open_pause_menu():
	if not pause_menu.visible:
		pause_menu_yes.disabled = false
		pause_menu_no.disabled = false
		pause_menu.visible = true


func close_pause_menu():
	pause_menu_yes.disabled = true
	pause_menu_no.disabled = true
	pause_menu.visible = false


func create_small_hud(data, new_agent):
	var new_small_hud = hud_agent_small_scene.instantiate()
	quick_views.add_child(new_small_hud)
	new_small_hud._health_bar.max_value = data.agent_stats.health
	new_small_hud._stun_health_bar.max_value = data.agent_stats.health / 2
	new_small_hud.ref_ag = new_agent


func update_text() -> void:
	ag_insts.text = ""
	for agent in game.agent_children():
		if agent.is_multiplayer_authority():
			ag_insts.text += agent.action_text + "\n"


func _on_radial_menu_no_decision_made() -> void:
	execute_button.visible = true
	execute_button.disabled = false

func pop_radial_menu_agent() -> Agent:
	var ret = radial_menu.referenced_agent
	radial_menu.clear_ref_ag()
	return ret


func create_agent_selector(agent : Agent):
	# check if selector already exists
	for s in (selectors.get_children() as Array[AgentSelector]):
		if s.referenced_agent == agent:
			return
	var new_selector = agent_selector_scene.instantiate()
	new_selector.referenced_agent = agent
	new_selector.agent_selected.connect(_hud_agent_details_actions)
	selectors.add_child(new_selector)


func _hud_agent_details_actions(agent_selector : AgentSelector):
	if server.game_phase != server.GamePhases.SELECTION:
		print(multiplayer.get_unique_id(), ": not in SELECTION MODE")
		return
	if server.selection_step != server.SelectionSteps.BASE:
		print(multiplayer.get_unique_id(), ": not on SelectionStep.BASE")
		return
	var agent = agent_selector.referenced_agent
	if agent.in_incapacitated_state() and not agent.percieved_by_friendly:
		print(multiplayer.get_unique_id(), ": agent is knocked out with no eyes on them")
		return
	agent.flash_outline(Color.AQUA)
	for small_hud in (quick_views.get_children()):
		if small_hud.ref_ag == agent:
			small_hud.flash = 1.0
	radial_menu.referenced_agent = agent
	radial_menu.position = agent_selector.position
	radial_menu.init_menu()
	execute_button.visible = false
	execute_button.disabled = true


func hide_hud():
	var twe = create_tween()
	twe.set_parallel(true)
	twe.set_trans(Tween.TRANS_CUBIC)
	twe.tween_property(execute_button, "position:y", 970, 0.25).from(825)
	#twe.tween_property(_quick_views, "position:y", 920, 0.25).from(712)
	twe.tween_property(ag_insts, "position:x", 1638, 0.25).from(1059)


func show_hud():
	var twe = create_tween()
	twe.set_parallel(true)
	twe.set_trans(Tween.TRANS_SINE)
	twe.tween_property(execute_button, "position:y", 825, 0.25).from(970)
	#twe.tween_property(_quick_views, "position:y", 712, 0.25).from(920)
	twe.tween_property(ag_insts, "position:x", 1059, 0.25).from(1638)


func show_hurryup():
	pass


func _on_no_forfeit_pressed() -> void:
	close_pause_menu()


func _on_execute_pressed() -> void:
	actions_submitted.play()
	execute_button.disabled = true
	execute_button.text = "WAITING FOR OPPONENT"
	for selector in selectors.get_children():
		selector.queue_free()
	radial_menu.button_collapse_animation()
	hide_hud()
