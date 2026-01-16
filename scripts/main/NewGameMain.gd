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
	draft_day_ui.visible = true

	# Load configs
	var config := _get_config()
	var league_cfg: Dictionary = config.get_config("world/league")
	var positions_cfg: Dictionary = config.get_config("positions")
	var stats_cfg: Dictionary = config.get_config("stats")
	var scouts_cfg: Dictionary = config.get_config("scouts")
	var main_cfg: Dictionary = config.get_config("main")

	# Create interactive draft
	var draft := InteractiveDraft.new()
	draft.initialize(
		_world_state,
		_session.current_year,
		base_seed if base_seed != 0 else int(Time.get_unix_time_from_system()),
		_session.user_team_id,
		league_cfg,
		positions_cfg,
		stats_cfg,
		scouts_cfg,
		main_cfg
	)

	# Initialize draft UI
	draft_day_ui.initialize(_session, draft)


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


func _show_error(message: String) -> void:
	loading_label.text = "ERROR: %s" % message
	loading_label.add_theme_color_override("font_color", Color.RED)
	loading_progress.visible = false


func _get_config() -> Node:
	if _config_instance == null:
		_config_instance = ConfigService.new()
	return _config_instance
