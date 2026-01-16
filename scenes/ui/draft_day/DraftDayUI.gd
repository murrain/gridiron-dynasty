## DraftDayUI - Main draft day interface
##
## This scene provides the full draft experience:
## - Draft ticker showing picks as they happen
## - Prospect list with available players
## - Detail card for selected prospect
## - Assistant coach recommendations panel
## - Draft action buttons
##
## Non-blocking actions (available at any time during draft):
## - View your roster
## - View other teams' rosters
## - Browse league standings
##
## Blocking action (draft waits for user):
## - Making a draft pick when it's your turn
##
## The draft proceeds automatically for AI teams. When it's the user's
## turn, the draft pauses and waits for the user to make a selection.
## While waiting, the user can still browse rosters and team info.
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
var _showing_roster_popup: bool = false
var _showing_teams_popup: bool = false

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
@onready var view_roster_button: Button = $MarginContainer/VBoxContainer/Footer/ViewRosterButton
@onready var view_teams_button: Button = $MarginContainer/VBoxContainer/Footer/ViewTeamsButton

## Popup references (created dynamically)
var _roster_popup: Window = null
var _teams_popup: Window = null


func _ready() -> void:
	prospect_list.item_selected.connect(_on_prospect_selected)
	draft_button.pressed.connect(_on_draft_button_pressed)
	view_world_button.pressed.connect(_on_view_world_pressed)
	view_roster_button.pressed.connect(_on_view_roster_pressed)
	view_teams_button.pressed.connect(_on_view_teams_pressed)
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


## Handle view roster button - NON-BLOCKING action
## User can view their roster at any time during the draft
func _on_view_roster_pressed() -> void:
	if _roster_popup != null and _roster_popup.visible:
		_roster_popup.hide()
		return

	_show_roster_popup()


## Handle view teams button - NON-BLOCKING action
## User can browse teams at any time during the draft
func _on_view_teams_pressed() -> void:
	if _teams_popup != null and _teams_popup.visible:
		_teams_popup.hide()
		return

	_show_teams_popup()


## Show roster popup window
func _show_roster_popup() -> void:
	if _roster_popup == null:
		_roster_popup = Window.new()
		_roster_popup.title = "My Roster"
		_roster_popup.size = Vector2i(500, 600)
		_roster_popup.close_requested.connect(_on_roster_popup_closed)
		add_child(_roster_popup)

	# Build roster content
	var container := VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.add_child(container)

	var roster := _session.get_user_roster()
	var players: Array = roster.get("players", [])

	var title := Label.new()
	title.text = "%s Roster (%d players)" % [_session.user_team_name, players.size()]
	title.add_theme_font_size_override("font_size", 18)
	container.add_child(title)

	var sep := HSeparator.new()
	container.add_child(sep)

	# Create scrollable player list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(scroll)

	var list := VBoxContainer.new()
	scroll.add_child(list)

	# Group by position
	var by_position := {}
	for player in players:
		var p: Dictionary = player
		var pos := String(p.get("position", "?"))
		if not by_position.has(pos):
			by_position[pos] = []
		by_position[pos].append(p)

	# Display by position
	var positions := ["QB", "RB", "WR", "TE", "OL", "DL", "EDGE", "LB", "CB", "S", "K", "P"]
	for pos in positions:
		if not by_position.has(pos):
			continue

		var pos_label := Label.new()
		pos_label.text = "--- %s ---" % pos
		pos_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		list.add_child(pos_label)

		for player in by_position[pos]:
			var p: Dictionary = player
			var player_label := Label.new()
			var name := String(p.get("name", "Unknown"))
			var ovr := float(p.get("composite_score", p.get("overall", 50.0)))
			var age := int(p.get("age", 22))
			player_label.text = "  %s - %.0f OVR, Age %d" % [name, ovr, age]
			list.add_child(player_label)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_on_roster_popup_closed)
	container.add_child(close_btn)

	# Clear and add content
	for child in _roster_popup.get_children():
		child.queue_free()
	_roster_popup.add_child(margin)

	_roster_popup.popup_centered()


## Show teams popup window
func _show_teams_popup() -> void:
	if _teams_popup == null:
		_teams_popup = Window.new()
		_teams_popup.title = "League Teams"
		_teams_popup.size = Vector2i(600, 700)
		_teams_popup.close_requested.connect(_on_teams_popup_closed)
		add_child(_teams_popup)

	# Build teams content
	var container := VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.add_child(container)

	var title := Label.new()
	title.text = "NFL Teams"
	title.add_theme_font_size_override("font_size", 18)
	container.add_child(title)

	var sep := HSeparator.new()
	container.add_child(sep)

	# Create scrollable team list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(scroll)

	var list := VBoxContainer.new()
	scroll.add_child(list)

	var teams: Array = _session.world_state.get("nfl_teams", [])
	var rosters: Dictionary = _session.world_state.get("nfl_rosters", {})

	# Sort teams by name
	var sorted_teams := teams.duplicate()
	sorted_teams.sort_custom(func(a, b):
		return String(a.get("name", "")) < String(b.get("name", ""))
	)

	for team in sorted_teams:
		var t: Dictionary = team
		var team_id := String(t.get("id", ""))
		var name := String(t.get("name", "Unknown"))
		var city := String(t.get("city", ""))

		var roster: Dictionary = rosters.get(team_id, {})
		var players: Array = roster.get("players", [])

		# Calculate team overall
		var total_ovr := 0.0
		for player in players:
			var p: Dictionary = player
			total_ovr += float(p.get("composite_score", p.get("overall", 50.0)))
		var avg_ovr := total_ovr / float(max(players.size(), 1))

		var is_user_team := team_id == _session.user_team_id

		var team_btn := Button.new()
		team_btn.text = "%s%s %s (%.0f OVR, %d players)" % [
			"* " if is_user_team else "",
			city,
			name,
			avg_ovr,
			players.size()
		]
		team_btn.pressed.connect(_on_team_clicked.bind(team_id))
		list.add_child(team_btn)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_on_teams_popup_closed)
	container.add_child(close_btn)

	# Clear and add content
	for child in _teams_popup.get_children():
		child.queue_free()
	_teams_popup.add_child(margin)

	_teams_popup.popup_centered()


## Handle team click in teams popup
func _on_team_clicked(team_id: String) -> void:
	# Show that team's roster in a simple dialog
	var teams: Array = _session.world_state.get("nfl_teams", [])
	var rosters: Dictionary = _session.world_state.get("nfl_rosters", {})

	var team_name := team_id
	for t in teams:
		if String(t.get("id", "")) == team_id:
			team_name = "%s %s" % [t.get("city", ""), t.get("name", "")]
			break

	var roster: Dictionary = rosters.get(team_id, {})
	var players: Array = roster.get("players", [])

	# Create simple dialog showing roster
	var dialog := AcceptDialog.new()
	dialog.title = team_name
	dialog.dialog_text = _format_team_roster(players)
	add_child(dialog)
	dialog.popup_centered()


## Format team roster for display
func _format_team_roster(players: Array) -> String:
	var lines: Array = []

	# Group by position
	var by_position := {}
	for player in players:
		var p: Dictionary = player
		var pos := String(p.get("position", "?"))
		if not by_position.has(pos):
			by_position[pos] = []
		by_position[pos].append(p)

	var positions := ["QB", "RB", "WR", "TE", "OL", "DL", "EDGE", "LB", "CB", "S"]
	for pos in positions:
		if not by_position.has(pos):
			continue
		lines.append("%s:" % pos)
		for player in by_position[pos]:
			var p: Dictionary = player
			var name := String(p.get("name", "Unknown"))
			var ovr := float(p.get("composite_score", p.get("overall", 50.0)))
			lines.append("  %s (%.0f)" % [name, ovr])

	return "\n".join(lines)


func _on_roster_popup_closed() -> void:
	if _roster_popup != null:
		_roster_popup.hide()


func _on_teams_popup_closed() -> void:
	if _teams_popup != null:
		_teams_popup.hide()
