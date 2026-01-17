## UDFABiddingUI - User interface for UDFA signing period
##
## This UI allows users to:
## - Browse eligible undrafted free agents
## - Select priority targets (up to 5)
## - View contract details for each UDFA
## - Confirm or skip the UDFA phase
##
## The UDFA phase is skippable and non-blocking for season advancement.
##
## Usage:
##   var udfa_ui = UDFABiddingUI.new()
##   add_child(udfa_ui)
##   udfa_ui.initialize(world_state, year, user_team_id, configs)
##   udfa_ui.udfa_phase_completed.connect(_on_udfa_completed)
##
extends Control
class_name UDFABiddingUI

const UDFABiddingEngine = preload("res://scripts/world/UDFABiddingEngine.gd")
const RookieWageScale = preload("res://scripts/core/contracts/RookieWageScale.gd")
const GameSession = preload("res://scripts/core/models/GameSession.gd")

signal udfa_phase_completed(results: Dictionary)
signal udfa_phase_skipped()

## Configuration
var _world_state: Dictionary = {}
var _year: int = 0
var _seed: int = 0
var _user_team_id: String = ""
var _league_cfg: Dictionary = {}
var _positions_cfg: Dictionary = {}
var _main_cfg: Dictionary = {}

## State
var _eligible_udfas: Array = []
var _selected_targets: Array = []  # Array of player_id strings
var _selected_player_id: String = ""

const MAX_TARGETS := 5

## UI References
@onready var header_label: Label = %HeaderLabel
@onready var instructions_label: Label = %InstructionsLabel
@onready var targets_label: Label = %TargetsLabel

@onready var udfa_list: ItemList = %UDFAList
@onready var position_filter: OptionButton = %PositionFilter

@onready var detail_panel: PanelContainer = %DetailPanel
@onready var player_name_label: Label = %PlayerNameLabel
@onready var player_position_label: Label = %PlayerPositionLabel
@onready var player_overall_label: Label = %PlayerOverallLabel
@onready var player_college_label: Label = %PlayerCollegeLabel
@onready var contract_label: Label = %ContractLabel

@onready var add_target_button: Button = %AddTargetButton
@onready var remove_target_button: Button = %RemoveTargetButton
@onready var confirm_button: Button = %ConfirmButton
@onready var skip_button: Button = %SkipButton

@onready var selected_targets_container: VBoxContainer = %SelectedTargetsContainer


func _ready() -> void:
	udfa_list.item_selected.connect(_on_udfa_selected)
	position_filter.item_selected.connect(_on_position_filter_changed)
	add_target_button.pressed.connect(_on_add_target_pressed)
	remove_target_button.pressed.connect(_on_remove_target_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	skip_button.pressed.connect(_on_skip_pressed)

	add_target_button.disabled = true
	remove_target_button.disabled = true

	_setup_position_filter()
	_clear_detail_panel()


## Initialize with world state and configuration
func initialize(
	world_state: Dictionary,
	year: int,
	seed: int,
	user_team_id: String,
	league_cfg: Dictionary,
	positions_cfg: Dictionary,
	main_cfg: Dictionary
) -> void:
	_world_state = world_state
	_year = year
	_seed = seed
	_user_team_id = user_team_id
	_league_cfg = league_cfg
	_positions_cfg = positions_cfg
	_main_cfg = main_cfg

	_selected_targets.clear()

	# Update header
	header_label.text = "%d UDFA Signing Period" % year
	instructions_label.text = "Select up to %d priority targets. You will get first claim on your targets." % MAX_TARGETS

	# Load eligible UDFAs
	_eligible_udfas = UDFABiddingEngine.get_eligible_udfas(
		world_state, year, positions_cfg, main_cfg, league_cfg
	)

	_populate_udfa_list()
	_update_targets_display()


## Initialize from a GameSession (convenience method)
func initialize_from_session(session: GameSession, seed: int) -> void:
	initialize(
		session.world_state,
		session.current_year,
		seed,
		session.user_team_id,
		session.world_state.get("league_cfg", {}),
		session.positions_cfg,
		session.main_cfg
	)


## Setup position filter dropdown
func _setup_position_filter() -> void:
	position_filter.clear()
	position_filter.add_item("All Positions", 0)
	var positions := ["QB", "RB", "WR", "TE", "OL", "DL", "EDGE", "LB", "CB", "S", "K", "P"]
	for i in range(positions.size()):
		position_filter.add_item(positions[i], i + 1)


## Populate UDFA list with eligible players
func _populate_udfa_list() -> void:
	udfa_list.clear()

	var filter_idx := position_filter.selected
	var position_filter_text := "" if filter_idx == 0 else position_filter.get_item_text(filter_idx)

	for udfa_entry in _eligible_udfas:
		var entry: Dictionary = udfa_entry
		var position := String(entry.get("position", ""))

		# Apply filter
		if not position_filter_text.is_empty() and position != position_filter_text:
			continue

		var player_id := String(entry.get("player_id", ""))
		var name := String(entry.get("name", "Unknown"))
		var overall := float(entry.get("overall", 50.0))

		# Mark if already selected
		var is_selected := player_id in _selected_targets
		var prefix := "[*] " if is_selected else ""

		var display_text := "%s%s %s - %.0f OVR" % [prefix, position, name, overall]
		var idx := udfa_list.add_item(display_text)
		udfa_list.set_item_metadata(idx, player_id)


## Handle UDFA selection
func _on_udfa_selected(index: int) -> void:
	if index < 0 or index >= udfa_list.item_count:
		return

	_selected_player_id = String(udfa_list.get_item_metadata(index))

	# Find player data
	var entry: Dictionary = {}
	for e in _eligible_udfas:
		if String(e.get("player_id", "")) == _selected_player_id:
			entry = e
			break

	if entry.is_empty():
		return

	var player: Dictionary = entry.get("player", {})
	var contract: Dictionary = entry.get("contract_preview", {})

	# Update detail panel
	player_name_label.text = String(entry.get("name", "Unknown"))
	player_position_label.text = String(entry.get("position", ""))
	player_overall_label.text = "Overall: %.0f" % float(entry.get("overall", 50.0))
	player_college_label.text = "College: %s" % String(player.get("college_team_id", "Unknown"))

	# Format contract
	var salary := float(contract.get("base_salary", 0))
	var years := int(contract.get("years_total", 3))
	contract_label.text = "Contract: $%.3fM/yr x %d years (no bonus, no guarantees)" % [salary, years]

	# Update button states
	var is_selected := _selected_player_id in _selected_targets
	add_target_button.disabled = is_selected or _selected_targets.size() >= MAX_TARGETS
	add_target_button.text = "Add Target" if not is_selected else "Already Selected"
	remove_target_button.disabled = not is_selected


## Handle position filter change
func _on_position_filter_changed(_index: int) -> void:
	_populate_udfa_list()


## Handle add target button
func _on_add_target_pressed() -> void:
	if _selected_player_id.is_empty():
		return

	if _selected_player_id in _selected_targets:
		return

	if _selected_targets.size() >= MAX_TARGETS:
		return

	_selected_targets.append(_selected_player_id)
	_update_targets_display()
	_populate_udfa_list()

	# Update button states
	add_target_button.disabled = true
	add_target_button.text = "Already Selected"
	remove_target_button.disabled = false


## Handle remove target button
func _on_remove_target_pressed() -> void:
	if _selected_player_id.is_empty():
		return

	if not _selected_player_id in _selected_targets:
		return

	_selected_targets.erase(_selected_player_id)
	_update_targets_display()
	_populate_udfa_list()

	# Update button states
	add_target_button.disabled = _selected_targets.size() >= MAX_TARGETS
	add_target_button.text = "Add Target"
	remove_target_button.disabled = true


## Update the selected targets display
func _update_targets_display() -> void:
	targets_label.text = "Selected Targets: %d / %d" % [_selected_targets.size(), MAX_TARGETS]

	# Clear existing
	for child in selected_targets_container.get_children():
		child.queue_free()

	# Add entries for each target
	for i in range(_selected_targets.size()):
		var player_id: String = _selected_targets[i]

		# Find player data
		var entry: Dictionary = {}
		for e in _eligible_udfas:
			if String(e.get("player_id", "")) == player_id:
				entry = e
				break

		var container := HBoxContainer.new()

		var rank_label := Label.new()
		rank_label.text = "#%d: " % (i + 1)
		container.add_child(rank_label)

		var name_label := Label.new()
		name_label.text = "%s %s (%.0f)" % [
			entry.get("position", "?"),
			entry.get("name", "Unknown"),
			entry.get("overall", 50.0)
		]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.add_child(name_label)

		var remove_btn := Button.new()
		remove_btn.text = "X"
		remove_btn.pressed.connect(_on_remove_target_by_id.bind(player_id))
		container.add_child(remove_btn)

		selected_targets_container.add_child(container)

	# Update confirm button
	confirm_button.text = "Sign %d UDFAs" % _selected_targets.size() if _selected_targets.size() > 0 else "Sign UDFAs"


## Remove a specific target by ID
func _on_remove_target_by_id(player_id: String) -> void:
	_selected_targets.erase(player_id)
	_update_targets_display()
	_populate_udfa_list()

	# Update button states if this was the selected player
	if player_id == _selected_player_id:
		add_target_button.disabled = _selected_targets.size() >= MAX_TARGETS
		add_target_button.text = "Add Target"
		remove_target_button.disabled = true


## Handle confirm button
func _on_confirm_pressed() -> void:
	# Validate targets
	var validation := UDFABiddingEngine.validate_user_targets(
		_selected_targets, _world_state, _year
	)

	if not validation.get("valid", false):
		push_error("UDFA validation failed: %s" % validation.get("error", "Unknown error"))
		return

	# Run UDFA bidding engine
	var results := UDFABiddingEngine.run(
		_world_state,
		_year,
		_seed,
		_user_team_id,
		_selected_targets,
		_league_cfg,
		_positions_cfg,
		_main_cfg
	)

	# Emit completion signal
	udfa_phase_completed.emit(results)


## Handle skip button
func _on_skip_pressed() -> void:
	# Run UDFA bidding with no user targets (AI only)
	var results := UDFABiddingEngine.run(
		_world_state,
		_year,
		_seed,
		_user_team_id,
		[],  # No user targets
		_league_cfg,
		_positions_cfg,
		_main_cfg
	)

	udfa_phase_skipped.emit()
	udfa_phase_completed.emit(results)


## Clear the detail panel
func _clear_detail_panel() -> void:
	player_name_label.text = "Select a Player"
	player_position_label.text = ""
	player_overall_label.text = ""
	player_college_label.text = ""
	contract_label.text = ""
	add_target_button.disabled = true
	remove_target_button.disabled = true


## Get current selection state (for save/restore)
func get_selection_state() -> Dictionary:
	return {
		"selected_targets": _selected_targets.duplicate(),
		"selected_player_id": _selected_player_id
	}


## Restore selection state (for save/restore)
func restore_selection_state(state: Dictionary) -> void:
	_selected_targets = (state.get("selected_targets", []) as Array).duplicate()
	_selected_player_id = String(state.get("selected_player_id", ""))
	_update_targets_display()
	_populate_udfa_list()
