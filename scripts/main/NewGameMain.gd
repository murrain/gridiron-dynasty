## NewGameMain - Orchestrates the new game experience
##
## Flow:
## 1. Loading screen while bootstrapping world (19 years)
## 2. Team selection UI - user picks their team
## 3. Draft day UI - user participates in the draft
## 4. World Explorer - view results and explore world
##
## This is the main entry point for starting a new game.
##
extends Node
class_name NewGameMain

const NewGameFlow = preload("res://scripts/pipelines/NewGameFlow.gd")
const InteractiveDraft = preload("res://scripts/world/InteractiveDraft.gd")
const GameSession = preload("res://scripts/core/models/GameSession.gd")
const ConfigService = preload("res://autoloads/Config.gd")
const DraftDayLauncher = preload("res://scripts/ui/draft_day/DraftDayLauncher.gd")

enum GamePhase { LOADING, TEAM_SELECTION, DRAFT, WORLD_EXPLORER }

@export var base_seed: int = 0
@export var years_of_history: int = 19

## UI References
@onready var loading_panel: PanelContainer = $MarginContainer/LoadingPanel
@onready var loading_label: Label = $MarginContainer/LoadingPanel/MarginContainer/VBoxContainer/LoadingLabel
@onready var loading_progress: ProgressBar = $MarginContainer/LoadingPanel/MarginContainer/VBoxContainer/LoadingProgress

@onready var team_selection_ui: Control = $MarginContainer/TeamSelectionUI
@onready var draft_day_ui: Control = $MarginContainer/DraftDayUI
@onready var world_explorer: Control = $MarginContainer/WorldExplorer

## State
var _phase: GamePhase = GamePhase.LOADING
var _session: GameSession = null
var _world_state: Dictionary = {}
var _config_instance: Node = null

## Draft turn tracking
var _is_user_turn: bool = false
var _current_pick_number: int = 0
var _current_round_number: int = 0

## Notification panel (created dynamically)
var _turn_notification: PanelContainer = null


func _ready() -> void:
	# Hide all panels initially
	loading_panel.visible = true
	team_selection_ui.visible = false
	draft_day_ui.visible = false
	world_explorer.visible = false

	# Connect signals
	team_selection_ui.team_selected.connect(_on_team_selected)
	draft_day_ui.draft_completed.connect(_on_draft_completed)
	draft_day_ui.view_world_requested.connect(_on_view_world_requested)
	draft_day_ui.user_turn_started.connect(_on_user_turn_started)
	draft_day_ui.user_turn_ended.connect(_on_user_turn_ended)

	# Start bootstrap
	call_deferred("_start_bootstrap")


func _start_bootstrap() -> void:
	loading_label.text = "Generating %d years of football history..." % years_of_history
	loading_progress.value = 0

	# Run new game flow in background
	var flow := NewGameFlow.new()
	flow.progress_callback = Callable(self, "_on_progress")

	print("[NewGameMain] Starting bootstrap with seed %d, %d years..." % [base_seed, years_of_history])

	var start_time := Time.get_ticks_usec()
	var result := flow.run(base_seed, years_of_history)
	var elapsed_ms := (Time.get_ticks_usec() - start_time) / 1000

	print("[NewGameMain] Bootstrap complete in %.2fs" % (elapsed_ms / 1000.0))

	if result.has("error"):
		_show_error(result.get("error", "Unknown error"))
		return

	_world_state = result.get("world_state", {})

	var available_teams: Array = result.get("available_teams", [])
	var draft_pool_size: int = result.get("draft_pool_size", 0)
	var current_year: int = result.get("current_year", 2025)

	print("[NewGameMain] World ready:")
	print("  - Year: %d" % current_year)
	print("  - Teams: %d" % available_teams.size())
	print("  - Draft pool: %d players" % draft_pool_size)

	# Move to team selection
	_show_team_selection(available_teams, current_year)


func _on_progress(phase_name: String, progress: float) -> void:
	loading_label.text = phase_name
	loading_progress.value = progress * 100


func _show_team_selection(teams: Array, year: int) -> void:
	_phase = GamePhase.TEAM_SELECTION

	loading_panel.visible = false
	team_selection_ui.visible = true

	team_selection_ui.set_teams(teams)


func _on_team_selected(team_id: String) -> void:
	print("[NewGameMain] User selected team: %s" % team_id)

	# Get year from world state
	var draft_pool_all: Dictionary = _world_state.get("draft_pool", {})
	var current_year := 0
	for year in draft_pool_all.keys():
		current_year = max(current_year, int(year))

	# Create game session
	_session = GameSession.new()
	_session.initialize(_world_state, team_id, current_year)

	print("[NewGameMain] Created session for %s in year %d" % [_session.user_team_name, current_year])

	# Move to draft
	_show_draft()


func _show_draft() -> void:
	_phase = GamePhase.DRAFT

	team_selection_ui.visible = false
	# Note: draft_day_ui will be created dynamically by DraftDayLauncher

	# Use DraftDayLauncher to create session, draft, and UI
	# This eliminates code duplication with BootstrapPreview
	var result := DraftDayLauncher.launch_with_team(
		_world_state,
		_session.current_year,
		_session.user_team_id,
		$MarginContainer  # Add to MarginContainer instead of root
	)

	if result.is_empty():
		push_error("[NewGameMain] Failed to launch draft")
		_show_error("Failed to initialize draft")
		return

	# Update our session reference (DraftDayLauncher created a new one)
	_session = result.get("session")
	var draft: InteractiveDraft = result.get("draft")
	var ui: Control = result.get("ui")

	# Store references for signal connections
	draft_day_ui = ui

	# Connect signals (DraftDayLauncher only handles initialization)
	if draft_day_ui.has_signal("draft_completed"):
		draft_day_ui.draft_completed.connect(_on_draft_completed)
	if draft_day_ui.has_signal("view_world_requested"):
		draft_day_ui.view_world_requested.connect(_on_view_world_requested)
	if draft_day_ui.has_signal("user_turn_started"):
		draft_day_ui.user_turn_started.connect(_on_user_turn_started)
	if draft_day_ui.has_signal("user_turn_ended"):
		draft_day_ui.user_turn_ended.connect(_on_user_turn_ended)

	draft_day_ui.visible = true
	print("[NewGameMain] Draft launched via DraftDayLauncher")


func _on_draft_completed(session: GameSession) -> void:
	print("[NewGameMain] Draft completed!")
	_session = session

	# User can now view world or continue
	# The DraftDayUI shows a "View World" button


func _on_view_world_requested() -> void:
	_show_world_explorer()


func _show_world_explorer() -> void:
	_phase = GamePhase.WORLD_EXPLORER

	draft_day_ui.visible = false
	world_explorer.visible = true

	# Load world state into explorer
	if world_explorer.has_method("load_world_state"):
		world_explorer.load_world_state(_world_state)

	# Show notification if it's still the user's turn in the draft
	if _is_user_turn:
		_show_turn_notification()


func _show_error(message: String) -> void:
	loading_label.text = "ERROR: %s" % message
	loading_label.add_theme_color_override("font_color", Color.RED)
	loading_progress.visible = false


func _get_config() -> Node:
	if _config_instance == null:
		_config_instance = ConfigService.new()
	return _config_instance


## Handle user turn started in draft
func _on_user_turn_started(pick_number: int, round_number: int) -> void:
	_is_user_turn = true
	_current_pick_number = pick_number
	_current_round_number = round_number

	# If user is not viewing the draft, show notification
	if _phase != GamePhase.DRAFT:
		_show_turn_notification()


## Handle user turn ended in draft
func _on_user_turn_ended() -> void:
	_is_user_turn = false
	_hide_turn_notification()


## Show the "It's your turn" notification
func _show_turn_notification() -> void:
	if _turn_notification != null:
		_turn_notification.visible = true
		# Update the pick info in case it changed
		var info_label := _turn_notification.get_node_or_null("MarginContainer/VBoxContainer/InfoLabel")
		if info_label:
			info_label.text = "Round %d, Pick #%d" % [_current_round_number, _current_pick_number]
		return

	# Create notification panel
	_turn_notification = PanelContainer.new()
	_turn_notification.anchor_left = 1.0
	_turn_notification.anchor_right = 1.0
	_turn_notification.anchor_top = 0.0
	_turn_notification.anchor_bottom = 0.0
	_turn_notification.offset_left = -320
	_turn_notification.offset_right = -20
	_turn_notification.offset_top = 20
	_turn_notification.offset_bottom = 140

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	_turn_notification.add_child(margin)

	var vbox := VBoxContainer.new()
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "IT'S YOUR TURN!"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	vbox.add_child(title)

	var info := Label.new()
	info.name = "InfoLabel"
	info.text = "Round %d, Pick #%d" % [_current_round_number, _current_pick_number]
	vbox.add_child(info)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	var return_btn := Button.new()
	return_btn.text = "Return to Draft"
	return_btn.pressed.connect(_on_return_to_draft_pressed)
	vbox.add_child(return_btn)

	add_child(_turn_notification)


## Hide the turn notification
func _hide_turn_notification() -> void:
	if _turn_notification != null:
		_turn_notification.visible = false


## Handle return to draft button
func _on_return_to_draft_pressed() -> void:
	_hide_turn_notification()
	_return_to_draft()


## Return to the draft screen
func _return_to_draft() -> void:
	_phase = GamePhase.DRAFT

	world_explorer.visible = false
	draft_day_ui.visible = true
