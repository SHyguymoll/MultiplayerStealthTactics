extends Node2D

@onready var quick_views : HBoxContainer = $HUDBase/QuickViews
@onready var radial_menu = $HUDSelected/RadialMenu
@onready var execute_button : Button = $HUDBase/Execute
@onready var phase_label : Label = $HUDBase/CurrentPhase
@onready var ag_insts : Label = $HUDBase/AgentInstructions

@onready var serv_name : Label = $HUDBase/ServerPlayerName
@onready var clie_name : Label = $HUDBase/ClientPlayerName
# Player progress bars
@onready var serv_prog : ProgressBar = $HUDBase/ProgressBarServer
@onready var clie_prog : ProgressBar = $HUDBase/ProgressBarClient


@onready var round_update : AudioStreamPlayer = $SoundEffects/RoundUpdate
@onready var round_ended : AudioStreamPlayer = $SoundEffects/RoundEnded
@onready var actions_submitted : AudioStreamPlayer = $SoundEffects/ActionsSubmitted

var hud_agent_small_scene = preload("res://scenes/hud_agent_small.tscn")
var popup_scene = preload("res://scenes/game_popup.tscn")
var audio_event_scene = preload("res://scenes/game_audio_event.tscn")
var toast_scene = preload("res://scenes/toast.tscn")
var agent_selector_scene = preload("res://scenes/agent_selector.tscn")

@onready var server = $"../MultiplayerHandler"
@onready var game = $".."

func _ready() -> void:
	radial_menu.visible = false
	close_pause_menu()

func animate_fade(in_out := true):
	var twe := create_tween()
	if in_out:
		twe.tween_property($FadeOut/ColorRect, "modulate", Color.WHITE, 1.5).from(Color.TRANSPARENT)
	else:
		twe.tween_property($FadeOut/ColorRect, "modulate", Color.TRANSPARENT, 1.5).from(Color.WHITE)

func create_toast(text : String, add_sound_effect : bool, color := Color(0.565, 0, 0.565, 0.212)):
	var new_toast : ToastMessage = toast_scene.instantiate()
	new_toast.input_text = text
	new_toast.color = color
	$HUDToasts/Toasts.add_child(new_toast)
	if add_sound_effect:
		round_update.play()
		pass
	pass


func open_pause_menu():
	if not $PauseMenu.visible:
		$PauseMenu/ColorRect/VBoxContainer/YesForfeit.disabled = false
		$PauseMenu/ColorRect/VBoxContainer/NoForfeit.disabled = false
		$PauseMenu.visible = true


func close_pause_menu():
	$PauseMenu/ColorRect/VBoxContainer/YesForfeit.disabled = true
	$PauseMenu/ColorRect/VBoxContainer/NoForfeit.disabled = true
	$PauseMenu.visible = false


func create_small_hud(data, new_agent):
	var new_small_hud = hud_agent_small_scene.instantiate()
	quick_views.add_child(new_small_hud)
	new_small_hud._health_bar.max_value = data.agent_stats.health
	new_small_hud._stun_health_bar.max_value = data.agent_stats.health / 2
	new_small_hud.ref_ag = new_agent


func update_text() -> void:
	ag_insts.text = ""
	for agent in ($Agents.get_children() as Array[Agent]):
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
	for s in ($HUDSelectors.get_children() as Array[AgentSelector]):
		if s.referenced_agent == agent:
			return
	var new_selector = agent_selector_scene.instantiate()
	new_selector.referenced_agent = agent
	new_selector.agent_selected.connect(_hud_agent_details_actions)
	$HUDSelectors.add_child(new_selector)


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
	for small_hud in ($HUDBase/QuickViews.get_children()):
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
