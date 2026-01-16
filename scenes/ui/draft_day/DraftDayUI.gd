## DraftDayUI - Main draft day interface
##
## This scene provides the full draft experience:
## - Draft ticker showing picks as they happen
## - Prospect list with available players
## - Detail card for selected prospect
## - Assistant coach recommendations panel
## - Draft action buttons
##
## Connects to InteractiveDraft for draft state management.
##
extends Control
class_name DraftDayUI

const InteractiveDraft = preload("res://scripts/world/InteractiveDraft.gd")
const GameSession = preload("res://scripts/core/models/GameSession.gd")

signal draft_completed(session: GameSession)
signal view_world_requested()

## References
var _draft: InteractiveDraft = null
var _session: GameSession = null

## State
var _available_players: Array = []
var _recommendations: Array = []
var _selected_player_id: String = ""

## UI References
@onready var header_label: Label = $MarginContainer/VBoxContainer/Header/HeaderLabel
@onready var round_label: Label = $MarginContainer/VBoxContainer/Header/RoundLabel
@onready var pick_label: Label = $MarginContainer/VBoxContainer/Header/PickLabel

@onready var draft_ticker: ItemList = $MarginContainer/VBoxContainer/MainContent/LeftPanel/DraftTicker/MarginContainer/TickerList
@onready var your_picks_label: Label = $MarginContainer/VBoxContainer/MainContent/LeftPanel/YourPicksPanel/MarginContainer/YourPicksLabel

@onready var prospect_list: ItemList = $MarginContainer/VBoxContainer/MainContent/CenterPanel/ProspectPanel/MarginContainer/VBoxContainer/ProspectList
@onready var position_filter: OptionButton = $MarginContainer/VBoxContainer/MainContent/CenterPanel/ProspectPanel/MarginContainer/VBoxContainer/FilterBar/PositionFilter

@onready var detail_panel: PanelContainer = $MarginContainer/VBoxContainer/MainContent/RightPanel/DetailPanel
@onready var prospect_name_label: Label = $MarginContainer/VBoxContainer/MainContent/RightPanel/DetailPanel/MarginContainer/VBoxContainer/ProspectNameLabel
@onready var prospect_position_label: Label = $MarginContainer/VBoxContainer/MainContent/RightPanel/DetailPanel/MarginContainer/VBoxContainer/ProspectPositionLabel
@onready var prospect_college_label: Label = $MarginContainer/VBoxContainer/MainContent/RightPanel/DetailPanel/MarginContainer/VBoxContainer/ProspectCollegeLabel
@onready var prospect_overall_label: Label = $MarginContainer/VBoxContainer/MainContent/RightPanel/DetailPanel/MarginContainer/VBoxContainer/ProspectOverallLabel
@onready var prospect_age_label: Label = $MarginContainer/VBoxContainer/MainContent/RightPanel/DetailPanel/MarginContainer/VBoxContainer/ProspectAgeLabel
@onready var draft_button: Button = $MarginContainer/VBoxContainer/MainContent/RightPanel/DetailPanel/MarginContainer/VBoxContainer/DraftButton

@onready var coach_panel: PanelContainer = $MarginContainer/VBoxContainer/MainContent/RightPanel/CoachPanel
@onready var rec_container: VBoxContainer = $MarginContainer/VBoxContainer/MainContent/RightPanel/CoachPanel/MarginContainer/VBoxContainer/RecommendationsContainer

@onready var status_label: Label = $MarginContainer/VBoxContainer/Footer/StatusLabel
@onready var view_world_button: Button = $MarginContainer/VBoxContainer/Footer/ViewWorldButton


func _ready() -> void:
	prospect_list.item_selected.connect(_on_prospect_selected)
	draft_button.pressed.connect(_on_draft_button_pressed)
	view_world_button.pressed.connect(_on_view_world_pressed)
	position_filter.item_selected.connect(_on_position_filter_changed)

	draft_button.disabled = true
	view_world_button.visible = false
	_clear_detail_panel()

	# Setup position filter
	_setup_position_filter()


## Initialize with session and draft controller
func initialize(session: GameSession, draft: InteractiveDraft) -> void:
	_session = session
	_draft = draft

	# Connect signals
	_draft.user_pick_requested.connect(_on_user_pick_requested)
	_draft.pick_made.connect(_on_pick_made)
	_draft.draft_completed.connect(_on_draft_completed)
	_draft.round_changed.connect(_on_round_changed)

	# Update header
	header_label.text = "%d NFL Draft - %s" % [session.current_year, session.user_team_name]

	# Start draft
	_draft.start()


## Setup position filter dropdown
func _setup_position_filter() -> void:
	position_filter.clear()
	position_filter.add_item("All Positions", 0)
	var positions := ["QB", "RB", "WR", "TE", "OL", "DL", "EDGE", "LB", "CB", "S", "K", "P"]
	for i in range(positions.size()):
		position_filter.add_item(positions[i], i + 1)


## Handle user pick request
func _on_user_pick_requested(pick_number: int, round_number: int, available: Array, recommendations: Array) -> void:
	_available_players = available
	_recommendations = recommendations

	pick_label.text = "Pick #%d" % pick_number
	round_label.text = "Round %d" % round_number
	status_label.text = "YOUR PICK! Select a player to draft."

	_populate_prospect_list()
	_populate_recommendations()

	draft_button.disabled = true
	_clear_detail_panel()


## Populate prospect list
func _populate_prospect_list() -> void:
	prospect_list.clear()

	var filter_idx := position_filter.selected
	var position_filter_text := "" if filter_idx == 0 else position_filter.get_item_text(filter_idx)

	for player in _available_players:
		var p: Dictionary = player
		var position := String(p.get("position", ""))

		# Apply filter
		if not position_filter_text.is_empty() and position != position_filter_text:
			continue

		var name := String(p.get("name", "Unknown"))
		var overall := float(p.get("overall", 50.0))
		var college := String(p.get("college", ""))

		var display_text := "%s %s - %.0f OVR" % [position, name, overall]
		if not college.is_empty():
			display_text += " (%s)" % college

		var idx := prospect_list.add_item(display_text)
		prospect_list.set_item_metadata(idx, p.get("player_id", ""))


## Populate recommendations
func _populate_recommendations() -> void:
	# Clear existing recommendations
	for child in rec_container.get_children():
		if child is Button:
			child.queue_free()

	# Add recommendation buttons
	for rec in _recommendations:
		var r: Dictionary = rec
		var btn := Button.new()
		btn.text = "#%d: %s %s (%.0f OVR) - %s" % [
			r.get("rank", 0),
			r.get("position", "?"),
			r.get("player_name", "Unknown"),
			r.get("overall", 50.0),
			r.get("college", "")
		]
		btn.pressed.connect(_on_recommendation_clicked.bind(String(r.get("player_id", ""))))
		rec_container.add_child(btn)


## Handle recommendation click
func _on_recommendation_clicked(player_id: String) -> void:
	# Select this player in the list
	for i in range(prospect_list.item_count):
		if prospect_list.get_item_metadata(i) == player_id:
			prospect_list.select(i)
			_on_prospect_selected(i)
			break

	# Make the pick immediately
	_make_pick(player_id)


## Handle prospect selection
func _on_prospect_selected(index: int) -> void:
	if index < 0 or index >= prospect_list.item_count:
		return

	_selected_player_id = String(prospect_list.get_item_metadata(index))

	# Find player data
	var player: Dictionary = {}
	for p in _available_players:
		if String(p.get("player_id", "")) == _selected_player_id:
			player = p
			break

	if player.is_empty():
		return

	# Update detail panel
	prospect_name_label.text = String(player.get("name", "Unknown"))
	prospect_position_label.text = String(player.get("position", ""))
	prospect_college_label.text = String(player.get("college", ""))
	prospect_overall_label.text = "Overall: %.0f" % float(player.get("overall", 50.0))
	prospect_age_label.text = "Age: %d" % int(player.get("age", 22))

	draft_button.disabled = false
	draft_button.text = "DRAFT %s" % String(player.get("name", "Unknown"))


## Handle draft button press
func _on_draft_button_pressed() -> void:
	if _selected_player_id.is_empty():
		return
	_make_pick(_selected_player_id)


## Make a pick
func _make_pick(player_id: String) -> void:
	draft_button.disabled = true
	status_label.text = "Making pick..."

	var success := _draft.make_user_pick(player_id)
	if not success:
		status_label.text = "Error making pick!"
		draft_button.disabled = false


## Handle pick made (AI or user)
func _on_pick_made(pick_info: Dictionary) -> void:
	# Add to ticker
	var text := "#%d %s: %s %s" % [
		pick_info.get("pick", 0),
		pick_info.get("team_id", ""),
		pick_info.get("position", ""),
		pick_info.get("player_name", "")
	]

	if pick_info.get("is_user_pick", false):
		text += " [YOUR PICK]"

	draft_ticker.add_item(text)
	draft_ticker.ensure_current_is_visible()

	# Update your picks display
	_update_your_picks()

	# Update status
	if not pick_info.get("is_user_pick", false):
		status_label.text = "Pick #%d: %s selects %s %s" % [
			pick_info.get("pick", 0),
			pick_info.get("team_id", ""),
			pick_info.get("position", ""),
			pick_info.get("player_name", "")
		]


## Update your picks display
func _update_your_picks() -> void:
	var your_picks := _draft.get_picks_made().filter(func(p):
		return p.get("is_user_pick", false)
	)

	var lines: Array = []
	for pick in your_picks:
		var p: Dictionary = pick
		lines.append("Rd %d #%d: %s %s" % [
			p.get("round", 0),
			p.get("pick", 0),
			p.get("position", ""),
			p.get("player_name", "")
		])

	if lines.is_empty():
		your_picks_label.text = "No picks yet"
	else:
		your_picks_label.text = "\n".join(lines)


## Handle round change
func _on_round_changed(round_number: int) -> void:
	round_label.text = "Round %d" % round_number
	status_label.text = "Round %d starting..." % round_number


## Handle draft completion
func _on_draft_completed(results: Dictionary) -> void:
	status_label.text = "DRAFT COMPLETE! You made %d picks." % results.get("user_picks", []).size()
	view_world_button.visible = true

	# Update session
	_session.draft_completed = true
	_session.advance_phase()

	draft_completed.emit(_session)


## Handle position filter change
func _on_position_filter_changed(_index: int) -> void:
	_populate_prospect_list()


## Handle view world button
func _on_view_world_pressed() -> void:
	view_world_requested.emit()


## Clear detail panel
func _clear_detail_panel() -> void:
	prospect_name_label.text = "Select a Prospect"
	prospect_position_label.text = ""
	prospect_college_label.text = ""
	prospect_overall_label.text = ""
	prospect_age_label.text = ""
	draft_button.text = "DRAFT"
	draft_button.disabled = true
