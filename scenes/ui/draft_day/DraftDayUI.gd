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
const PlayerShortlistPanel = preload("res://scenes/ui/draft_day/PlayerShortlistPanel.gd")
const SchemeFitModifier = preload("res://scripts/core/evaluation/modifiers/SchemeFitModifier.gd")
const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")
const TradeProposalDialogScript = preload("res://scenes/ui/draft_day/TradeProposalDialog.gd")
const PreDraftRosterViewScript = preload("res://scenes/ui/draft/PreDraftRosterView.gd")
const UserPickModalScript = preload("res://scenes/ui/draft/UserPickModal.gd")

signal draft_completed(session: GameSession)
signal view_world_requested()
signal user_turn_started(pick_number: int, round_number: int)
signal user_turn_ended()

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

## Scheme fit display label (created dynamically)
var _scheme_fit_label: Label = null

@onready var coach_panel: PanelContainer = $MarginContainer/VBoxContainer/MainContent/RightPanel/CoachPanel
@onready var rec_container: VBoxContainer = $MarginContainer/VBoxContainer/MainContent/RightPanel/CoachPanel/MarginContainer/VBoxContainer/RecommendationsContainer

@onready var status_label: Label = $MarginContainer/VBoxContainer/Footer/StatusLabel
@onready var view_world_button: Button = $MarginContainer/VBoxContainer/Footer/ViewWorldButton
@onready var view_roster_button: Button = $MarginContainer/VBoxContainer/Footer/ViewRosterButton
@onready var view_teams_button: Button = $MarginContainer/VBoxContainer/Footer/ViewTeamsButton
@onready var propose_trade_button: Button = $MarginContainer/VBoxContainer/Footer/ProposeTradeButton

## Popup references (created dynamically)
var _roster_popup: Window = null
var _teams_popup: Window = null

## Shortlist panel reference (if available in scene tree)
var _shortlist_panel: PlayerShortlistPanel = null

## Board sort mode toggle (created dynamically if not in scene)
var _board_sort_toggle: OptionButton = null

## Shortlist button for selected player
var _shortlist_button: Button = null

## Trade dialog reference (created dynamically)
var _trade_dialog: Window = null

## Pre-draft roster view panel (for roster context during draft)
var _roster_view: PreDraftRosterViewScript = null

## User pick modal (embedded panel for user pick selection - Engineer 2)
var _user_pick_modal: UserPickModalScript = null

## Whether to use modal for user picks (can be toggled for different UX)
var _use_pick_modal: bool = true


func _ready() -> void:
	# Validate critical UI nodes exist
	if not prospect_list:
		push_warning("[DraftDayUI] prospect_list node not found - UI may not function correctly")
		return

	if not draft_button:
		push_warning("[DraftDayUI] draft_button node not found - UI may not function correctly")
		return

	if not position_filter:
		push_warning("[DraftDayUI] position_filter node not found - filtering will be disabled")

	if not header_label:
		push_warning("[DraftDayUI] header_label node not found - header display will be missing")

	if not status_label:
		push_warning("[DraftDayUI] status_label node not found - status updates will be missing")

	if not draft_ticker:
		push_warning("[DraftDayUI] draft_ticker node not found - draft ticker will be missing")

	# Connect signals only if nodes exist
	if prospect_list:
		prospect_list.item_selected.connect(_on_prospect_selected)

	if draft_button:
		draft_button.pressed.connect(_on_draft_button_pressed)
		draft_button.disabled = true

	if view_world_button:
		view_world_button.pressed.connect(_on_view_world_pressed)
		view_world_button.visible = false

	if view_roster_button:
		view_roster_button.pressed.connect(_on_view_roster_pressed)

	if view_teams_button:
		view_teams_button.pressed.connect(_on_view_teams_pressed)

	if position_filter:
		position_filter.item_selected.connect(_on_position_filter_changed)

	_clear_detail_panel()

	# Setup position filter
	_setup_position_filter()

	# Setup board sort toggle (DRAFT-015)
	_setup_board_sort_toggle()

	# Setup Propose Trade button (DRAFT-001)
	_setup_propose_trade_button()

	# Setup user pick modal (Engineer 2)
	_setup_user_pick_modal()

	# Setup QoL features (Engineer 4)
	_setup_qol_features()

	# Enable multi-select for player comparison
	_enable_multi_select_for_comparison()


## Initialize with session and draft controller
func initialize(session: GameSession, draft: InteractiveDraft) -> void:
	_session = session
	_draft = draft

	# Connect signals
	_draft.user_pick_requested.connect(_on_user_pick_requested)
	_draft.pick_made.connect(_on_pick_made)
	_draft.draft_completed.connect(_on_draft_completed)
	_draft.round_changed.connect(_on_round_changed)

	# Connect shortlist signals (DRAFT-009)
	_draft.shortlisted_player_drafted.connect(_on_shortlisted_player_drafted)

	# Connect trade signals (DRAFT-001)
	_draft.trade_executed.connect(_on_trade_executed)

	# Initialize shortlist panel if exists
	_setup_shortlist_panel()

	# Initialize trade dialog
	_setup_trade_dialog()

	# Initialize roster context panel (Engineer 3)
	_setup_roster_view()

	# Update header
	header_label.text = "%d NFL Draft - %s" % [session.current_year, session.user_team_name]

	# Start draft
	_draft.start()


## Setup position filter dropdown
func _setup_position_filter() -> void:
	if not position_filter:
		push_warning("[DraftDayUI] Cannot setup position filter - node is null")
		return

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

	# Show user pick modal if enabled (Engineer 2)
	if _use_pick_modal and _user_pick_modal != null:
		_user_pick_modal.show_pick(round_number, pick_number, available)

	# Start pick timer (Engineer 4)
	_start_pick_timer_for_user()

	# Notify that it's the user's turn (for external notification systems)
	user_turn_started.emit(pick_number, round_number)


## Populate prospect list
## Uses the draft's sorted available players when draft is available
func _populate_prospect_list() -> void:
	# If draft is available, use sorted list that respects current sort mode
	if _draft:
		_populate_prospect_list_sorted()
		return

	# Fallback for when draft is not yet initialized
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

	# Find player data - try sorted list first, then fallback to _available_players
	var player: Dictionary = {}
	if _draft:
		var sorted_players := _draft.get_sorted_available_players()
		for p in sorted_players:
			if String(p.get("player_id", "")) == _selected_player_id:
				player = p
				break

	if player.is_empty():
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

	# Update scheme fit display (DRAFT-011)
	_update_scheme_fit_display(player)

	draft_button.disabled = false
	draft_button.text = "DRAFT %s" % String(player.get("name", "Unknown"))

	# Setup shortlist button if not already created
	_setup_shortlist_button()

	# Update shortlist button state
	if _draft:
		_update_shortlist_button_state(_draft.is_on_shortlist(_selected_player_id))


## Handle draft button press
func _on_draft_button_pressed() -> void:
	if _selected_player_id.is_empty():
		return
	_make_pick(_selected_player_id)


## Make a pick
func _make_pick(player_id: String) -> void:
	draft_button.disabled = true
	status_label.text = "Making pick..."

	# Stop pick timer (Engineer 4)
	_stop_pick_timer()

	# Notify that the user's turn is ending
	user_turn_ended.emit()

	# Show draft grade before making pick (Engineer 4)
	_show_draft_grade(player_id)

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

	# Refresh roster view if user made the pick (Engineer 3)
	if pick_info.get("is_user_pick", false) and _roster_view != null:
		_roster_view.refresh_after_pick(pick_info)


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

	# Clear scheme fit display (DRAFT-011)
	if _scheme_fit_label:
		_scheme_fit_label.text = ""


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


# =============================================================================
# SHORTLIST INTEGRATION (DRAFT-009)
# =============================================================================

## Setup the shortlist panel
func _setup_shortlist_panel() -> void:
	# Try to find existing shortlist panel in scene tree
	_shortlist_panel = get_node_or_null("MarginContainer/VBoxContainer/MainContent/LeftPanel/ShortlistPanel") as PlayerShortlistPanel

	if _shortlist_panel == null:
		# Create shortlist panel dynamically
		var panel_scene := load("res://scenes/ui/draft_day/PlayerShortlistPanel.tscn")
		if panel_scene:
			_shortlist_panel = panel_scene.instantiate() as PlayerShortlistPanel
			# Add to left panel
			var left_panel := get_node_or_null("MarginContainer/VBoxContainer/MainContent/LeftPanel")
			if left_panel:
				left_panel.add_child(_shortlist_panel)

	if _shortlist_panel and _draft:
		_shortlist_panel.initialize(_draft)
		_shortlist_panel.player_selected.connect(_on_shortlist_player_selected)


# =============================================================================
# PRE-DRAFT ROSTER VIEW (Engineer 3)
# =============================================================================

## Setup the pre-draft roster view panel
## Shows current roster, position needs, and depth chart to inform draft decisions
func _setup_roster_view() -> void:
	if _session == null:
		push_warning("[DraftDayUI] Cannot setup roster view - session is null")
		return

	# Only show roster view if user has a team selected
	if _session.user_team_id.is_empty():
		return

	# Try to find existing roster view in scene tree
	_roster_view = get_node_or_null("MarginContainer/VBoxContainer/MainContent/LeftPanel/RosterView") as PreDraftRosterViewScript

	if _roster_view == null:
		# Create roster view dynamically
		var roster_view_scene := load("res://scenes/ui/draft/PreDraftRosterView.tscn")
		if roster_view_scene:
			_roster_view = roster_view_scene.instantiate() as PreDraftRosterViewScript
			_roster_view.name = "RosterView"
			_roster_view.custom_minimum_size = Vector2(280, 300)

			# Add to left panel (below ticker and your picks)
			var left_panel := get_node_or_null("MarginContainer/VBoxContainer/MainContent/LeftPanel")
			if left_panel:
				left_panel.add_child(_roster_view)
		else:
			push_warning("[DraftDayUI] Could not load PreDraftRosterView.tscn")
			return

	if _roster_view:
		# Get configs for position needs calculation
		var positions_cfg: Dictionary = _session.world_state.get("positions_cfg", {})
		var main_cfg: Dictionary = _session.world_state.get("main_cfg", {})

		# If configs not in world_state, try to load them
		if positions_cfg.is_empty():
			positions_cfg = _session.get_config("positions", {}) if _session.has_method("get_config") else {}
		if main_cfg.is_empty():
			main_cfg = _session.get_config("main", {}) if _session.has_method("get_config") else {}

		# Initialize with team data
		_roster_view.initialize(
			_session.user_team_id,
			_session.world_state,
			positions_cfg,
			main_cfg
		)
		_roster_view.visible = true

		# Log render time for performance monitoring
		var render_time := _roster_view.get_last_render_time_ms()
		if render_time > 0:
			print("[DraftDayUI] Roster view rendered in %.1fms" % render_time)


## Handle shortlist player selection
func _on_shortlist_player_selected(player_id: String) -> void:
	# Select this player in the prospect list
	for i in range(prospect_list.item_count):
		if prospect_list.get_item_metadata(i) == player_id:
			prospect_list.select(i)
			_on_prospect_selected(i)
			break


## Handle shortlisted player drafted notification
func _on_shortlisted_player_drafted(player_id: String, player_name: String, position: String, team_id: String, pick_number: int) -> void:
	# The shortlist panel handles its own alert, but we update the status bar too
	status_label.text = "ALERT: %s %s drafted by %s (Pick #%d)" % [position, player_name, team_id, pick_number]


## Toggle shortlist status for selected player
func _toggle_shortlist() -> void:
	if _draft == null or _selected_player_id.is_empty():
		return

	if _draft.is_on_shortlist(_selected_player_id):
		_draft.remove_from_shortlist(_selected_player_id)
		_update_shortlist_button_state(false)
	else:
		_draft.add_to_shortlist(_selected_player_id)
		_update_shortlist_button_state(true)


## Update shortlist button appearance
func _update_shortlist_button_state(is_shortlisted: bool) -> void:
	if _shortlist_button:
		if is_shortlisted:
			_shortlist_button.text = "[*] Remove from Watchlist"
		else:
			_shortlist_button.text = "[ ] Add to Watchlist"


## Setup shortlist button in detail panel
func _setup_shortlist_button() -> void:
	if _shortlist_button:
		return  # Already created

	# Find the detail panel's VBoxContainer
	var detail_vbox := get_node_or_null("MarginContainer/VBoxContainer/MainContent/RightPanel/DetailPanel/MarginContainer/VBoxContainer")
	if detail_vbox == null:
		push_warning("[DraftDayUI] Cannot setup shortlist button - detail_vbox node not found")
		return

	if not draft_button:
		push_warning("[DraftDayUI] Cannot setup shortlist button - draft_button is null")
		return

	# Create the shortlist button
	_shortlist_button = Button.new()
	_shortlist_button.text = "[ ] Add to Watchlist"
	_shortlist_button.tooltip_text = "Add/remove this player from your watchlist"
	_shortlist_button.pressed.connect(_toggle_shortlist)

	# Insert before the draft button
	var draft_btn_idx := draft_button.get_index()
	detail_vbox.add_child(_shortlist_button)
	detail_vbox.move_child(_shortlist_button, draft_btn_idx)


# =============================================================================
# BOARD SORT MODE TOGGLE (DRAFT-015)
# =============================================================================

## Setup board sort toggle dropdown
func _setup_board_sort_toggle() -> void:
	# Try to find existing toggle in filter bar
	var filter_bar := get_node_or_null("MarginContainer/VBoxContainer/MainContent/CenterPanel/ProspectPanel/MarginContainer/VBoxContainer/FilterBar")

	if filter_bar == null:
		push_warning("[DraftDayUI] Cannot setup board sort toggle - filter_bar node not found")
		return

	# Create the toggle dropdown
	_board_sort_toggle = OptionButton.new()
	_board_sort_toggle.add_item("BPA (Best Player Available)", 0)
	_board_sort_toggle.add_item("Need (Team Needs)", 1)
	_board_sort_toggle.add_item("Scheme Fit", 2)
	_board_sort_toggle.tooltip_text = "Sort prospect list by: BPA, Need, or Scheme Fit"
	_board_sort_toggle.item_selected.connect(_on_board_sort_changed)

	filter_bar.add_child(_board_sort_toggle)


## Handle board sort mode change
func _on_board_sort_changed(index: int) -> void:
	if _draft == null:
		return

	match index:
		0:
			_draft.set_board_sort_mode(InteractiveDraft.BoardSortMode.BPA)
		1:
			_draft.set_board_sort_mode(InteractiveDraft.BoardSortMode.NEED)
		2:
			_draft.set_board_sort_mode(InteractiveDraft.BoardSortMode.SCHEME_FIT)

	# Refresh the prospect list with new sort
	_populate_prospect_list_sorted()


## Populate prospect list using the draft's sorted available players
## PERFORMANCE: Uses get_sorted_with_shortlist() for O(n) instead of O(n²)
func _populate_prospect_list_sorted() -> void:
	prospect_list.clear()

	if _draft == null:
		return

	var filter_idx := position_filter.selected
	var position_filter_text := "" if filter_idx == 0 else position_filter.get_item_text(filter_idx)

	# Get sorted players with shortlist state included (O(n) performance)
	var sorted_players: Array = _draft.get_sorted_with_shortlist()

	for player in sorted_players:
		var p: Dictionary = player
		var position := String(p.get("position", ""))

		# Apply position filter
		if not position_filter_text.is_empty() and position != position_filter_text:
			continue

		var name := String(p.get("name", "Unknown"))
		var overall := float(p.get("overall", 50.0))
		var college := String(p.get("college", ""))
		var player_id := String(p.get("player_id", ""))

		# Shortlist state is already included in player dict (O(n) instead of O(n²))
		var is_shortlisted := bool(p.get("_is_shortlisted", false))

		# Build display text with shortlist indicator
		var display_text := ""
		if is_shortlisted:
			display_text = "[*] "
		display_text += "%s %s - %.0f OVR" % [position, name, overall]
		if not college.is_empty():
			display_text += " (%s)" % college

		var idx := prospect_list.add_item(display_text)
		prospect_list.set_item_metadata(idx, player_id)

		# Color shortlisted players differently
		if is_shortlisted:
			prospect_list.set_item_custom_fg_color(idx, Color(0.3, 0.8, 0.3))


# =============================================================================
# DRAFT TRADING SYSTEM (DRAFT-001)
# =============================================================================

## Setup the Propose Trade button in the footer
func _setup_propose_trade_button() -> void:
	# Connect the Propose Trade button from scene
	if propose_trade_button:
		propose_trade_button.pressed.connect(_on_propose_trade_pressed)
	else:
		push_warning("[DraftDayUI] Cannot setup Propose Trade button - node not found in scene")


## Setup the trade proposal dialog
func _setup_trade_dialog() -> void:
	if _trade_dialog != null:
		return  # Already created

	# Load TradeProposalDialog scene
	var dialog_scene := load("res://scenes/ui/draft_day/TradeProposalDialog.tscn")
	if dialog_scene:
		_trade_dialog = dialog_scene.instantiate()
		add_child(_trade_dialog)

		# Connect signals
		_trade_dialog.trade_proposed.connect(_on_trade_proposal_submitted)
		_trade_dialog.trade_cancelled.connect(_on_trade_proposal_cancelled)
	else:
		push_warning("[DraftDayUI] Could not load TradeProposalDialog.tscn")


## Handle Propose Trade button press
func _on_propose_trade_pressed() -> void:
	if _draft == null:
		push_warning("[DraftDayUI] Cannot propose trade - draft not initialized")
		return

	if _trade_dialog == null:
		_setup_trade_dialog()

	if _trade_dialog == null:
		push_warning("[DraftDayUI] Cannot propose trade - dialog creation failed")
		return

	# Check if trading is enabled
	if not _draft.is_trading_enabled():
		status_label.text = "Trading is disabled for this draft."
		return

	# Get user's tradeable picks
	var user_picks := _draft.get_user_tradeable_picks()
	if user_picks.is_empty():
		status_label.text = "You have no picks available to trade."
		return

	# Get list of teams to trade with (exclude user's team)
	var all_teams: Array = _session.world_state.get("nfl_teams", [])
	var available_teams: Array = []
	for team in all_teams:
		var t: Dictionary = team
		if String(t.get("id", "")) != _session.user_team_id:
			available_teams.append(t)

	# Get pick ownership
	var ownership: Dictionary = _session.world_state.get("draft_pick_ownership", {})
	var year := _session.current_year
	var league_cfg: Dictionary = _session.get_config("league", {})

	# Open the dialog
	_trade_dialog.open_dialog(
		_session.user_team_id,
		available_teams,
		user_picks,
		ownership,
		year,
		league_cfg
	)


## Handle trade proposal submitted from dialog
func _on_trade_proposal_submitted(offer: Dictionary) -> void:
	if _draft == null:
		push_error("[DraftDayUI] Cannot process trade - draft not initialized")
		return

	# Close the dialog
	_trade_dialog.hide()

	# Extract trade details
	var target_team_id := String(offer.get("receiving_team_id", ""))
	var picks_offered: Array = offer.get("picks_offered", []) as Array
	var picks_requested: Array = offer.get("picks_requested", []) as Array

	# Get target team name for display
	var target_team_name := _get_team_name(target_team_id)

	# Submit the trade proposal
	status_label.text = "Proposing trade to %s..." % target_team_name

	var result := _draft.propose_user_trade(target_team_id, picks_offered, picks_requested)

	if not bool(result.get("success")):
		# Trade failed (validation error)
		status_label.text = "Trade failed: %s" % String(result.get("reason", "Unknown error"))
		_show_trade_result_dialog("Trade Failed", String(result.get("reason", "Unknown error")))
		return

	if bool(result.get("accepted")):
		# Trade was accepted
		var message := "%s accepted your trade offer!" % target_team_name
		status_label.text = message
		_show_trade_result_dialog("Trade Accepted!", message)
	else:
		# Trade was declined
		var message := "%s declined your trade offer." % target_team_name
		status_label.text = message
		_show_trade_result_dialog("Trade Declined", message)


## Handle trade proposal cancelled
func _on_trade_proposal_cancelled() -> void:
	status_label.text = "Trade proposal cancelled."


## Handle trade executed (from InteractiveDraft signal)
func _on_trade_executed(trade_record: Dictionary) -> void:
	var offering_team := String(trade_record.get("offering_team_id", ""))
	var receiving_team := String(trade_record.get("receiving_team_id", ""))
	var initiated_by := String(trade_record.get("initiated_by", "ai"))

	var offering_name := _get_team_name(offering_team)
	var receiving_name := _get_team_name(receiving_team)

	# Add to draft ticker
	var ticker_text := "[TRADE] %s and %s have completed a trade!" % [offering_name, receiving_name]
	draft_ticker.add_item(ticker_text)
	draft_ticker.ensure_current_is_visible()

	# Update status if it was an AI trade
	if initiated_by == "ai":
		status_label.text = "Trade completed: %s and %s" % [offering_name, receiving_name]


## Show trade result dialog
func _show_trade_result_dialog(title: String, message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()


## Get team display name from team ID
func _get_team_name(team_id: String) -> String:
	var teams: Array = _session.world_state.get("nfl_teams", [])
	for team in teams:
		var t: Dictionary = team
		if String(t.get("id", "")) == team_id:
			return "%s %s" % [String(t.get("city", "")), String(t.get("name", ""))]
	return team_id


# =============================================================================
# SCHEME FIT DISPLAY (DRAFT-011)
# =============================================================================

## Setup scheme fit label in detail panel
func _setup_scheme_fit_label() -> void:
	if _scheme_fit_label:
		return  # Already created

	# Find the detail panel's VBoxContainer
	var detail_vbox := get_node_or_null("MarginContainer/VBoxContainer/MainContent/RightPanel/DetailPanel/MarginContainer/VBoxContainer")
	if detail_vbox == null:
		push_warning("[DraftDayUI] Cannot setup scheme fit label - detail_vbox node not found")
		return

	# Create the scheme fit label
	_scheme_fit_label = Label.new()
	_scheme_fit_label.text = ""
	_scheme_fit_label.tooltip_text = "How well this player fits your team's scheme"

	# Insert after prospect_age_label (if it exists)
	if prospect_age_label and prospect_age_label.get_parent() == detail_vbox:
		var age_idx := prospect_age_label.get_index()
		detail_vbox.add_child(_scheme_fit_label)
		detail_vbox.move_child(_scheme_fit_label, age_idx + 1)
	else:
		# Fallback: add at the end
		detail_vbox.add_child(_scheme_fit_label)


## Update scheme fit display for selected player
## Calculates and displays scheme fit score based on user's team scheme
func _update_scheme_fit_display(player: Dictionary) -> void:
	if _session == null or _draft == null:
		return

	# Ensure label exists
	_setup_scheme_fit_label()

	if _scheme_fit_label == null:
		return

	# Get player data
	var position := String(player.get("position", ""))

	# Special teams don't have scheme fit
	if position in ["K", "P"]:
		_scheme_fit_label.text = "Scheme Fit: N/A"
		_scheme_fit_label.modulate = Color.WHITE
		return

	# Get full player data from draft (has stats needed for scheme fit calculation)
	var full_player := _draft.get_player_by_id(String(player.get("player_id", "")))
	if full_player.is_empty():
		full_player = player

	# Get user team's schemes
	var user_team := _get_user_team_data()
	var offensive_scheme := String(user_team.get("offensive_scheme", "pro_style"))
	var defensive_scheme := String(user_team.get("defensive_scheme", "cover_2"))
	var coach: Dictionary = user_team.get("coach", {})
	var coach_rigidity := float(coach.get("scheme_rigidity", 1.0))

	# Calculate base rating
	var class_rules: Dictionary = _session.world_state.get("class_rules", {})
	var positions_cfg: Dictionary = _session.world_state.get("positions_cfg", {})
	var base_rating := float(player.get("overall", 50.0))

	# Calculate scheme fit score using SchemeFitModifier
	var scheme_score := SchemeFitModifier.calculate_scheme_fit_score(
		full_player,
		position,
		base_rating,
		offensive_scheme,
		defensive_scheme,
		coach_rigidity
	)

	# Get grade letter
	var grade := SchemeFitModifier.get_scheme_fit_grade(scheme_score)

	# Set text with grade
	_scheme_fit_label.text = "Scheme Fit: %s (%.0f)" % [grade, scheme_score]

	# Color based on fit quality
	if scheme_score >= 80:
		_scheme_fit_label.modulate = Color(0.3, 0.9, 0.3)  # Green - excellent fit
		_scheme_fit_label.tooltip_text = "Excellent scheme fit - this player's attributes match your %s perfectly" % _get_relevant_scheme_name(position, offensive_scheme, defensive_scheme)
	elif scheme_score >= 60:
		_scheme_fit_label.modulate = Color(0.9, 0.9, 0.3)  # Yellow - good fit
		_scheme_fit_label.tooltip_text = "Good scheme fit - this player would work well in your %s" % _get_relevant_scheme_name(position, offensive_scheme, defensive_scheme)
	elif scheme_score >= 40:
		_scheme_fit_label.modulate = Color.WHITE  # White - neutral
		_scheme_fit_label.tooltip_text = "Average scheme fit - this player could adapt to your %s" % _get_relevant_scheme_name(position, offensive_scheme, defensive_scheme)
	else:
		_scheme_fit_label.modulate = Color(0.9, 0.3, 0.3)  # Red - poor fit
		_scheme_fit_label.tooltip_text = "Poor scheme fit - this player's style doesn't match your %s" % _get_relevant_scheme_name(position, offensive_scheme, defensive_scheme)


## Get user team data from session
func _get_user_team_data() -> Dictionary:
	if _session == null:
		return {}

	var teams: Array = _session.world_state.get("nfl_teams", [])
	for team in teams:
		var t: Dictionary = team
		if String(t.get("id", "")) == _session.user_team_id:
			return t
	return {}


## Get relevant scheme name for display (offensive or defensive based on position)
func _get_relevant_scheme_name(position: String, offensive_scheme: String, defensive_scheme: String) -> String:
	var offensive_positions := ["QB", "RB", "WR", "TE", "OL"]
	if position in offensive_positions:
		return offensive_scheme.replace("_", " ") + " offense"
	return defensive_scheme.replace("_", " ") + " defense"


# =============================================================================
# USER PICK MODAL (Engineer 2)
# =============================================================================

## Setup the user pick modal as an embedded panel
## The modal provides an overlay experience for making draft picks
## Performance target: Modal should render in <100ms
func _setup_user_pick_modal() -> void:
	if _user_pick_modal != null:
		return  # Already created

	# Try to find existing modal in scene tree (if added via .tscn)
	_user_pick_modal = get_node_or_null("UserPickModal") as UserPickModalScript

	if _user_pick_modal == null:
		# Create modal dynamically
		var modal_scene := load("res://scenes/ui/draft/UserPickModal.tscn")
		if modal_scene:
			_user_pick_modal = modal_scene.instantiate() as UserPickModalScript
			_user_pick_modal.name = "UserPickModal"
			# Add as child so it overlays the main content
			add_child(_user_pick_modal)

			# Connect signals
			_user_pick_modal.player_selected.connect(_on_modal_player_selected)
			_user_pick_modal.auto_pick_requested.connect(_on_modal_auto_pick_requested)

			# Start hidden
			_user_pick_modal.visible = false
		else:
			push_warning("[DraftDayUI] Could not load UserPickModal.tscn")
	else:
		# Connect signals if modal was found in scene tree
		_user_pick_modal.player_selected.connect(_on_modal_player_selected)
		_user_pick_modal.auto_pick_requested.connect(_on_modal_auto_pick_requested)


## Handle player selection from the user pick modal
func _on_modal_player_selected(player_id: String) -> void:
	if player_id.is_empty():
		push_warning("[DraftDayUI] Modal returned empty player_id")
		return

	_make_pick(player_id)


## Handle auto-pick BPA request from the user pick modal
func _on_modal_auto_pick_requested() -> void:
	if _draft == null:
		push_error("[DraftDayUI] Cannot auto-pick - draft is null")
		return

	# Get recommendations using public API
	var recommendations := _draft.get_recommendations(1)
	if recommendations.is_empty():
		push_warning("[DraftDayUI] No recommendations available for auto-pick")
		# Fallback: pick the first available player
		if not _available_players.is_empty():
			var first_player: Dictionary = _available_players[0]
			var player_id := String(first_player.get("player_id", ""))
			if not player_id.is_empty():
				_make_pick(player_id)
		return

	var best_player: Dictionary = recommendations[0]
	var player_id := String(best_player.get("player_id", ""))
	if player_id.is_empty():
		push_error("[DraftDayUI] Best player recommendation has empty player_id")
		return

	_make_pick(player_id)


## Toggle whether to use the modal for user picks
## Can be called from settings or debug panel
func set_use_pick_modal(enabled: bool) -> void:
	_use_pick_modal = enabled

	# Hide modal if disabling while visible
	if not enabled and _user_pick_modal != null and _user_pick_modal.visible:
		_user_pick_modal.hide_modal()


## Check if pick modal is currently being used
func is_using_pick_modal() -> bool:
	return _use_pick_modal


## Get the user pick modal reference (for external access if needed)
func get_user_pick_modal() -> UserPickModalScript:
	return _user_pick_modal


# =============================================================================
# QUALITY OF LIFE FEATURES (Engineer 4)
# =============================================================================

## Import QoL components
const PlayerComparisonViewScript = preload("res://scenes/ui/draft/PlayerComparisonView.gd")
const PickTimerScript = preload("res://scenes/ui/draft/PickTimer.gd")
const DraftGrader = preload("res://scripts/world/DraftGrader.gd")
const MockDraftGenerator = preload("res://scripts/world/MockDraftGenerator.gd")
const TeamNeeds = preload("res://scripts/core/roster/TeamNeeds.gd")

## QoL UI references (created dynamically)
## NOTE: _advanced_filter removed - we integrate with existing position_filter instead
var _comparison_view: PlayerComparisonViewScript = null
var _pick_timer: PickTimerScript = null
var _compare_button: Button = null
var _grader: DraftGrader = null

## QoL state
var _filtered_players: Array = []
var _last_grade_result: Dictionary = {}


## Setup QoL features (called from _ready or initialize)
func _setup_qol_features() -> void:
	_setup_advanced_filter()
	_setup_comparison_view()
	_setup_pick_timer()
	_setup_compare_button()
	_grader = DraftGrader.new()


## Setup advanced filter bar
## NOTE: This integrates with the existing position_filter in FilterBar
## rather than creating a duplicate filter bar component.
func _setup_advanced_filter() -> void:
	# Note: Advanced filtering (search, multi-sort) should be implemented
	# by enhancing the existing FilterBar controls, not creating a separate
	# DraftBoardFilter component. This keeps the UI unified.
	pass


## Setup comparison view modal
func _setup_comparison_view() -> void:
	var view_scene := load("res://scenes/ui/draft/PlayerComparisonView.tscn")
	if view_scene:
		_comparison_view = view_scene.instantiate() as PlayerComparisonViewScript
		if _comparison_view:
			add_child(_comparison_view)
			_comparison_view.player_chosen.connect(_on_comparison_player_chosen)
			_comparison_view.comparison_closed.connect(_on_comparison_closed)


## Setup pick timer
func _setup_pick_timer() -> void:
	var timer_scene := load("res://scenes/ui/draft/PickTimer.tscn")
	if timer_scene:
		_pick_timer = timer_scene.instantiate() as PickTimerScript
		if _pick_timer:
			# Add to header area
			var header := get_node_or_null("MarginContainer/VBoxContainer/Header")
			if header:
				header.add_child(_pick_timer)
				_pick_timer.time_expired.connect(_on_pick_timer_expired)


## Setup compare button in the detail panel
func _setup_compare_button() -> void:
	var detail_vbox := get_node_or_null("MarginContainer/VBoxContainer/MainContent/RightPanel/DetailPanel/MarginContainer/VBoxContainer")
	if detail_vbox == null:
		return

	if _compare_button:
		return  # Already created

	_compare_button = Button.new()
	_compare_button.text = "Compare Players"
	_compare_button.tooltip_text = "Select 2-3 players from the list to compare (Ctrl+click)"
	_compare_button.disabled = true
	_compare_button.pressed.connect(_on_compare_button_pressed)

	# Insert before draft button
	if draft_button and draft_button.get_parent() == detail_vbox:
		var btn_idx := draft_button.get_index()
		detail_vbox.add_child(_compare_button)
		detail_vbox.move_child(_compare_button, btn_idx)


## Apply advanced filters to player list
## NOTE: This is called manually or could be connected to enhanced filter controls
func _apply_advanced_filters(position_filter_val: String, search_val: String, sort_mode: String) -> void:
	if _draft == null:
		return

	# Get base player list
	var all_players := _draft.get_sorted_available_players()

	# Apply position filter
	if position_filter_val != "All":
		all_players = all_players.filter(func(p):
			return String(p.get("position", "")) == position_filter_val
		)

	# Apply name search
	if not search_val.is_empty():
		var search_lower := search_val.to_lower()
		all_players = all_players.filter(func(p):
			return search_lower in String(p.get("name", "")).to_lower()
		)

	# Apply sort mode
	match sort_mode:
		"Overall":
			all_players.sort_custom(func(a, b):
				return float(a.get("overall", 0.0)) > float(b.get("overall", 0.0))
			)
		"Scheme Fit":
			_sort_by_scheme_fit_qol(all_players)
		"Position Need":
			_sort_by_position_need_qol(all_players)
		"Mock Rank":
			_sort_by_mock_rank(all_players)

	_filtered_players = all_players
	_populate_prospect_list_from_array(_filtered_players)


## Sort players by scheme fit (QoL version)
func _sort_by_scheme_fit_qol(players: Array) -> void:
	var user_team := _get_user_team_data()
	var offensive_scheme := String(user_team.get("offensive_scheme", "pro_style"))
	var defensive_scheme := String(user_team.get("defensive_scheme", "cover_2"))

	for player in players:
		var p: Dictionary = player
		var position := String(p.get("position", ""))
		var scheme_fit: Dictionary = p.get("scheme_fit", {})

		var scheme := offensive_scheme
		if position in ["DL", "EDGE", "LB", "CB", "S"]:
			scheme = defensive_scheme

		var fit := float(scheme_fit.get(scheme, 75.0))
		p["_sort_score"] = fit

	players.sort_custom(func(a, b):
		return float(a.get("_sort_score", 0.0)) > float(b.get("_sort_score", 0.0))
	)


## Sort players by position need (QoL version)
func _sort_by_position_need_qol(players: Array) -> void:
	if _session == null:
		return

	# Get team needs
	var roster_data: Dictionary = _session.get_user_roster()
	var needs := _calculate_simple_needs(roster_data)

	# Apply need multiplier to overall for sorting
	for player in players:
		var p: Dictionary = player
		var position := String(p.get("position", ""))
		var overall := float(p.get("overall", 50.0))
		var need_mult := float(needs.get(position, 1.0))
		p["_sort_score"] = overall * need_mult

	players.sort_custom(func(a, b):
		return float(a.get("_sort_score", 0.0)) > float(b.get("_sort_score", 0.0))
	)


## Sort players by mock draft rank
func _sort_by_mock_rank(players: Array) -> void:
	for player in players:
		var p: Dictionary = player
		var projection := MockDraftGenerator.get_latest_projection(p)
		var rank := int(projection.get("projected_pick", 999))
		p["_sort_score"] = -rank  # Negative so lower rank = higher score

	players.sort_custom(func(a, b):
		return float(a.get("_sort_score", 0.0)) > float(b.get("_sort_score", 0.0))
	)


## Populate prospect list from filtered array
func _populate_prospect_list_from_array(players: Array) -> void:
	prospect_list.clear()

	for player in players:
		var p: Dictionary = player
		var position := String(p.get("position", ""))
		var player_name := String(p.get("name", "Unknown"))
		var overall := float(p.get("overall", 50.0))
		var college := String(p.get("college", p.get("college_team_id", "")))
		var player_id := String(p.get("player_id", ""))

		# Check shortlist state
		var is_shortlisted := false
		if _draft:
			is_shortlisted = _draft.is_on_shortlist(player_id)

		var display_text := ""
		if is_shortlisted:
			display_text = "[*] "
		display_text += "%s %s - %.0f OVR" % [position, player_name, overall]
		if not college.is_empty():
			display_text += " (%s)" % college

		var idx := prospect_list.add_item(display_text)
		prospect_list.set_item_metadata(idx, player_id)

		if is_shortlisted:
			prospect_list.set_item_custom_fg_color(idx, Color(0.3, 0.8, 0.3))


## Handle compare button press
func _on_compare_button_pressed() -> void:
	var selected := prospect_list.get_selected_items()
	if selected.size() < 2:
		status_label.text = "Select 2-3 players to compare (Ctrl+click to multi-select)"
		return

	# Get player data for comparison
	var players_to_compare: Array = []
	for idx in selected:
		if players_to_compare.size() >= 3:
			break
		var player_id := String(prospect_list.get_item_metadata(idx))
		var player := _draft.get_player_by_id(player_id)
		if not player.is_empty():
			players_to_compare.append(player)

	if players_to_compare.size() < 2:
		status_label.text = "Could not load player data for comparison"
		return

	# Get config for comparison view
	var positions_cfg: Dictionary = {}
	var class_rules: Dictionary = {}
	var team_scheme := ""

	if _session:
		positions_cfg = _session.world_state.get("positions_cfg", {})
		class_rules = _session.world_state.get("class_rules", {})
		var user_team := _get_user_team_data()
		team_scheme = String(user_team.get("offensive_scheme", "pro_style"))

	_comparison_view.show_comparison(players_to_compare, positions_cfg, class_rules, team_scheme)


## Handle player chosen from comparison view
func _on_comparison_player_chosen(player_id: String) -> void:
	# Select this player and make the pick
	_selected_player_id = player_id

	# Find and select in list
	for i in range(prospect_list.item_count):
		if prospect_list.get_item_metadata(i) == player_id:
			prospect_list.select(i)
			_on_prospect_selected(i)
			break

	# Optionally auto-draft
	_make_pick(player_id)


## Handle comparison view closed
func _on_comparison_closed() -> void:
	status_label.text = "Comparison closed - select a player to draft"


## Handle pick timer expiry - auto-pick BPA
func _on_pick_timer_expired() -> void:
	if _draft == null:
		return

	status_label.text = "Time's up! Auto-picking best player available..."

	# Get BPA from recommendations using public API
	var recommendations := _draft.get_recommendations(1)
	if not recommendations.is_empty():
		var bpa: Dictionary = recommendations[0]
		var player_id := String(bpa.get("player_id", ""))
		if not player_id.is_empty():
			_make_pick(player_id)
			return

	# Fallback: pick first player in list
	if prospect_list.item_count > 0:
		var first_player_id := String(prospect_list.get_item_metadata(0))
		_make_pick(first_player_id)


## Start pick timer when user's turn begins
func _start_pick_timer_for_user() -> void:
	if _pick_timer and _pick_timer.is_timer_enabled():
		_pick_timer.start_timer(300.0)  # 5 minutes


## Stop pick timer when user makes pick
func _stop_pick_timer() -> void:
	if _pick_timer:
		_pick_timer.stop_timer()


## Prepare data needed for draft grade calculation
## @return Dictionary with all required fields, or empty dict if data unavailable
##
## This helper method validates all data dependencies and aggregates them
## into a single structure, making _show_draft_grade() testable and debuggable.
func _prepare_grade_data(player: Dictionary, pick_number: int) -> Dictionary:
	# Validate session data availability
	var roster_data := _session.get_user_roster()
	if roster_data.is_empty():
		push_warning("[DraftDayUI] Cannot calculate draft grade - roster data unavailable")
		return {}

	# Calculate position needs
	var needs := _calculate_simple_needs(roster_data)
	if needs.is_empty():
		push_warning("[DraftDayUI] Cannot calculate draft grade - needs calculation failed")
		return {}

	# Get user team data for scheme
	var user_team := _get_user_team_data()
	if user_team.is_empty():
		push_warning("[DraftDayUI] Cannot calculate draft grade - user team data unavailable")
		return {}

	# Determine relevant scheme based on position
	var position := String(player.get("position", ""))
	var team_scheme := _get_team_scheme_for_position(user_team, position)

	# Get consensus rank from mock draft
	var projection := MockDraftGenerator.get_latest_projection(player)
	var consensus_rank := int(projection.get("projected_pick", pick_number))

	# Get required configs
	var positions_cfg: Dictionary = _session.world_state.get("positions_cfg", {})
	var class_rules: Dictionary = _session.world_state.get("class_rules", {})

	if positions_cfg.is_empty():
		push_warning("[DraftDayUI] Cannot calculate draft grade - positions_cfg unavailable")
		return {}

	if class_rules.is_empty():
		push_warning("[DraftDayUI] Cannot calculate draft grade - class_rules unavailable")
		return {}

	return {
		"needs": needs,
		"team_scheme": team_scheme,
		"consensus_rank": consensus_rank,
		"positions_cfg": positions_cfg,
		"class_rules": class_rules
	}


## Get the relevant team scheme (offensive or defensive) for a given position
## @param user_team: Team data dictionary containing scheme information
## @param position: Player position string
## @return Scheme name string
func _get_team_scheme_for_position(user_team: Dictionary, position: String) -> String:
	var offensive_positions := ["QB", "RB", "WR", "TE", "OL"]
	if position in offensive_positions:
		return String(user_team.get("offensive_scheme", "pro_style"))
	else:
		return String(user_team.get("defensive_scheme", "cover_2"))


## Show draft grade after user makes a pick
func _show_draft_grade(player_id: String) -> void:
	if _grader == null or _draft == null or _session == null:
		return

	var player := _draft.get_player_by_id(player_id)
	if player.is_empty():
		push_warning("[DraftDayUI] Cannot calculate draft grade - player not found")
		return

	var pick_number := _draft.get_current_pick()
	var round_number := _draft.get_current_round()

	# Prepare all required data with validation
	var grade_data := _prepare_grade_data(player, pick_number)
	if grade_data.is_empty():
		push_warning("[DraftDayUI] Cannot calculate draft grade - missing data")
		return

	# Calculate grade using validated data
	var grade_result := _grader.grade_pick(
		player,
		pick_number,
		round_number,
		grade_data.get("needs"),
		grade_data.get("team_scheme"),
		grade_data.get("consensus_rank"),
		grade_data.get("positions_cfg"),
		grade_data.get("class_rules")
	)

	_last_grade_result = grade_result

	# Display grade popup
	_display_grade_popup(grade_result)


## Calculate simple needs from roster
func _calculate_simple_needs(roster_data: Dictionary) -> Dictionary:
	var by_position: Dictionary = {}
	for player in roster_data.get("players", []):
		var pos := String(player.get("position", ""))
		if not by_position.has(pos):
			by_position[pos] = 0
		by_position[pos] = int(by_position[pos]) + 1

	var ideal_counts := {
		"QB": 3, "RB": 4, "WR": 6, "TE": 3, "OL": 10,
		"DL": 5, "EDGE": 4, "LB": 6, "CB": 6, "S": 4, "K": 1, "P": 1
	}

	var needs := {}
	for pos in ideal_counts.keys():
		var current := int(by_position.get(pos, 0))
		var ideal := int(ideal_counts.get(pos, 3))
		if current == 0:
			needs[pos] = 1.5
		elif current < ideal:
			needs[pos] = 1.0 + (float(ideal - current) / float(ideal)) * 0.3
		else:
			needs[pos] = 0.95

	return needs


## Display draft grade popup
func _display_grade_popup(grade_result: Dictionary) -> void:
	var letter := String(grade_result.get("letter_grade", "C"))
	var analysis := String(grade_result.get("analysis", ""))
	var overall_score := float(grade_result.get("overall_score", 70.0))

	var dialog := AcceptDialog.new()
	dialog.title = "Draft Grade: %s" % letter
	dialog.dialog_text = "Grade: %s (%.0f)\n\n%s" % [letter, overall_score, analysis]

	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())

	add_child(dialog)
	dialog.popup_centered()


## Enable multi-select on prospect list for comparison
func _enable_multi_select_for_comparison() -> void:
	if prospect_list:
		prospect_list.select_mode = ItemList.SELECT_MULTI


## Update compare button state based on selection
func _update_compare_button_state() -> void:
	if _compare_button:
		var selected_count := prospect_list.get_selected_items().size()
		_compare_button.disabled = selected_count < 2
		if selected_count >= 2:
			_compare_button.text = "Compare %d Players" % min(selected_count, 3)
		else:
			_compare_button.text = "Compare Players"


## Get the last calculated draft grade
func get_last_grade() -> Dictionary:
	return _last_grade_result


## Check if QoL features are enabled
func is_qol_enabled() -> bool:
	return _grader != null
