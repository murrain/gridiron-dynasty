## DraftHistoryViewer - UI for reviewing historical drafts
##
## This viewer allows users to:
## - Browse past drafts (up to 10 years back)
## - See pick-by-pick analysis with player outcomes
## - Identify busts and steals with hindsight
## - View round-by-round success rates
## - Compare draft classes
##
## Usage:
##   var viewer = DraftHistoryViewer.new()
##   add_child(viewer)
##   viewer.initialize(world_state, current_year, positions_cfg)
##
extends Control
class_name DraftHistoryViewer

const DraftHistoryAnalyzer = preload("res://scripts/world/DraftHistoryAnalyzer.gd")
const GameSession = preload("res://scripts/core/models/GameSession.gd")

signal close_requested()

## Configuration
var _world_state: Dictionary = {}
var _current_year: int = 0
var _positions_cfg: Dictionary = {}

## State
var _selected_year: int = 0
var _current_analysis: Dictionary = {}
var _available_years: Array = []

## UI References
@onready var header_label: Label = %HeaderLabel
@onready var year_selector: OptionButton = %YearSelector
@onready var summary_label: Label = %SummaryLabel

@onready var picks_list: ItemList = %PicksList
@onready var round_filter: OptionButton = %RoundFilter

@onready var detail_panel: PanelContainer = %DetailPanel
@onready var player_name_label: Label = %PlayerNameLabel
@onready var draft_info_label: Label = %DraftInfoLabel
@onready var career_label: Label = %CareerLabel
@onready var accolades_label: Label = %AccoladesLabel
@onready var verdict_label: Label = %VerdictLabel

@onready var busts_container: VBoxContainer = %BustsContainer
@onready var steals_container: VBoxContainer = %StealsContainer
@onready var rounds_container: VBoxContainer = %RoundsContainer

@onready var close_button: Button = %CloseButton


func _ready() -> void:
	year_selector.item_selected.connect(_on_year_selected)
	round_filter.item_selected.connect(_on_round_filter_changed)
	picks_list.item_selected.connect(_on_pick_selected)
	close_button.pressed.connect(_on_close_pressed)

	_setup_round_filter()


## Initialize with world state
func initialize(
	world_state: Dictionary,
	current_year: int,
	positions_cfg: Dictionary
) -> void:
	_world_state = world_state
	_current_year = current_year
	_positions_cfg = positions_cfg

	header_label.text = "Draft History Viewer"

	# Get available draft years
	_available_years = DraftHistoryAnalyzer.get_available_draft_years(world_state)

	# Populate year selector
	year_selector.clear()
	for year in _available_years:
		var years_ago := current_year - year
		year_selector.add_item("%d (%d years ago)" % [year, years_ago], year)

	# Select most recent year by default
	if _available_years.size() > 0:
		year_selector.select(year_selector.item_count - 1)
		_on_year_selected(year_selector.item_count - 1)


## Initialize from a GameSession
func initialize_from_session(session: GameSession) -> void:
	initialize(
		session.world_state,
		session.current_year,
		session.positions_cfg
	)


## Setup round filter
func _setup_round_filter() -> void:
	round_filter.clear()
	round_filter.add_item("All Rounds", 0)
	for r in range(1, 8):
		round_filter.add_item("Round %d" % r, r)


## Handle year selection
func _on_year_selected(index: int) -> void:
	_selected_year = year_selector.get_item_id(index)

	# Run analysis
	_current_analysis = DraftHistoryAnalyzer.analyze_draft_class(
		_selected_year, _current_year, _world_state, _positions_cfg
	)

	if _current_analysis.has("error"):
		summary_label.text = "Error: %s" % _current_analysis.get("error", "Unknown")
		return

	_update_summary()
	_populate_picks_list()
	_populate_busts()
	_populate_steals()
	_populate_rounds()


## Update summary display
func _update_summary() -> void:
	var years_elapsed := int(_current_analysis.get("years_elapsed", 0))
	var total_picks := int(_current_analysis.get("total_picks", 0))
	var pro_bowlers := int(_current_analysis.get("pro_bowlers", 0))
	var all_pros := int(_current_analysis.get("all_pros", 0))
	var active := int(_current_analysis.get("active_players", 0))
	var retired := int(_current_analysis.get("retired_players", 0))

	var text := "%d NFL Draft - %d Years Later\n" % [_selected_year, years_elapsed]
	text += "Total Picks: %d | Pro Bowlers: %d | All-Pros: %d\n" % [total_picks, pro_bowlers, all_pros]
	text += "Still Active: %d | Retired: %d" % [active, retired]

	if years_elapsed < 3:
		text += "\n(Analysis limited - less than 3 years of data)"

	summary_label.text = text


## Populate picks list
func _populate_picks_list() -> void:
	picks_list.clear()

	var filter_round := round_filter.get_item_id(round_filter.selected)
	var picks: Array = _current_analysis.get("picks", [])
	var players_status: Dictionary = _current_analysis.get("players_status", {})

	for pick in picks:
		var p: Dictionary = pick
		var round_num := int(p.get("round", 0))

		# Apply filter
		if filter_round > 0 and round_num != filter_round:
			continue

		var pick_num := int(p.get("pick", 0))
		var player_id := String(p.get("player_id", ""))
		var player_name := String(p.get("player_name", "Unknown"))
		var position := String(p.get("position", ""))

		var status: Dictionary = players_status.get(player_id, {})
		var pro_bowls := int(status.get("pro_bowls", 0))
		var starter_years := int(status.get("years_as_starter", 0))

		# Create display with verdict indicator
		var indicator := ""
		if pro_bowls > 0:
			indicator = "[*] "  # Pro Bowler
		elif starter_years >= 3:
			indicator = "[+] "  # Solid starter
		elif starter_years < 2 and pick_num <= 50:
			indicator = "[-] "  # Potential bust
		elif status.get("is_retired", false) and pick_num <= 100:
			indicator = "[X] "  # Out of league early

		var display := "%s#%d (Rd %d): %s %s" % [indicator, pick_num, round_num, position, player_name]
		var idx := picks_list.add_item(display)
		picks_list.set_item_metadata(idx, player_id)


## Handle pick selection
func _on_pick_selected(index: int) -> void:
	if index < 0 or index >= picks_list.item_count:
		return

	var player_id := String(picks_list.get_item_metadata(index))
	var players_status: Dictionary = _current_analysis.get("players_status", {})
	var status: Dictionary = players_status.get(player_id, {})

	if status.is_empty():
		return

	# Update detail panel
	player_name_label.text = String(status.get("player_name", "Unknown"))

	var pick := int(status.get("draft_pick", 0))
	var round_num := int(status.get("draft_round", 0))
	var position := String(status.get("position", ""))
	draft_info_label.text = "Pick #%d (Round %d) - %s" % [pick, round_num, position]

	var starter_years := int(status.get("years_as_starter", 0))
	var career_games := int(status.get("career_games", 0))
	var is_active := bool(status.get("is_active", false))
	var status_text := "Active" if is_active else "Retired"
	career_label.text = "Status: %s | Starter Years: %d | Career Games: %d" % [
		status_text, starter_years, career_games
	]

	var pro_bowls := int(status.get("pro_bowls", 0))
	var all_pros := int(status.get("all_pros", 0))
	if pro_bowls > 0 or all_pros > 0:
		accolades_label.text = "Pro Bowls: %d | All-Pros: %d" % [pro_bowls, all_pros]
		accolades_label.visible = true
	else:
		accolades_label.text = "No major accolades"
		accolades_label.visible = true

	# Determine verdict
	var verdict := _determine_verdict(pick, status)
	verdict_label.text = verdict.text
	verdict_label.modulate = verdict.color


## Determine verdict for a pick
func _determine_verdict(pick_num: int, status: Dictionary) -> Dictionary:
	var pro_bowls := int(status.get("pro_bowls", 0))
	var all_pros := int(status.get("all_pros", 0))
	var starter_years := int(status.get("years_as_starter", 0))
	var is_retired := bool(status.get("is_retired", false))

	if all_pros > 0:
		return {"text": "ELITE - All-Pro caliber player", "color": Color(0.2, 1.0, 0.2)}
	elif pro_bowls > 0:
		return {"text": "SUCCESS - Pro Bowl selection", "color": Color(0.4, 0.9, 0.4)}
	elif starter_years >= 5:
		return {"text": "GOOD VALUE - Long-term starter", "color": Color(0.6, 0.8, 0.4)}
	elif starter_years >= 3:
		return {"text": "SOLID - Quality starter", "color": Color(0.8, 0.8, 0.4)}
	elif starter_years >= 1:
		return {"text": "ROLE PLAYER - Some contributions", "color": Color(0.8, 0.7, 0.4)}
	elif is_retired and pick_num <= 50:
		return {"text": "BUST - Out of league early", "color": Color(1.0, 0.3, 0.3)}
	elif pick_num <= 50 and starter_years < 2:
		return {"text": "DISAPPOINTING - Never became starter", "color": Color(1.0, 0.5, 0.3)}
	else:
		return {"text": "DEPTH - Career backup", "color": Color(0.7, 0.7, 0.7)}


## Handle round filter change
func _on_round_filter_changed(_index: int) -> void:
	_populate_picks_list()


## Populate busts section
func _populate_busts() -> void:
	for child in busts_container.get_children():
		child.queue_free()

	var busts: Array = _current_analysis.get("busts", [])

	if busts.is_empty():
		var label := Label.new()
		label.text = "No significant busts identified"
		label.modulate = Color(0.6, 0.6, 0.6)
		busts_container.add_child(label)
		return

	for bust in busts.slice(0, 5):  # Show top 5 busts
		var b: Dictionary = bust
		var label := Label.new()
		label.text = "#%d %s %s - %s" % [
			b.get("pick", 0),
			b.get("position", ""),
			b.get("player_name", ""),
			b.get("reason", "")
		]
		label.modulate = Color(1.0, 0.5, 0.5)
		busts_container.add_child(label)


## Populate steals section
func _populate_steals() -> void:
	for child in steals_container.get_children():
		child.queue_free()

	var steals: Array = _current_analysis.get("steals", [])

	if steals.is_empty():
		var label := Label.new()
		label.text = "No steals identified (yet)"
		label.modulate = Color(0.6, 0.6, 0.6)
		steals_container.add_child(label)
		return

	for steal in steals.slice(0, 5):  # Show top 5 steals
		var s: Dictionary = steal
		var label := Label.new()
		label.text = "#%d %s %s - %s" % [
			s.get("pick", 0),
			s.get("position", ""),
			s.get("player_name", ""),
			s.get("achievement", "")
		]
		label.modulate = Color(0.5, 1.0, 0.5)
		steals_container.add_child(label)


## Populate rounds breakdown
func _populate_rounds() -> void:
	for child in rounds_container.get_children():
		child.queue_free()

	var round_breakdown: Dictionary = _current_analysis.get("round_breakdown", {})

	for round_num in range(1, 8):
		var key := "round_%d" % round_num
		var data: Dictionary = round_breakdown.get(key, {})

		if data.is_empty():
			continue

		var total := int(data.get("total_picks", 0))
		var starters := int(data.get("starters", 0))
		var pro_bowls := int(data.get("pro_bowls", 0))
		var success_rate := float(data.get("success_rate", 0))

		var label := Label.new()
		label.text = "Round %d: %d picks, %d starters (%.0f%%), %d Pro Bowls" % [
			round_num, total, starters, success_rate, pro_bowls
		]
		rounds_container.add_child(label)


## Handle close button
func _on_close_pressed() -> void:
	close_requested.emit()


## Get current analysis (for external access)
func get_current_analysis() -> Dictionary:
	return _current_analysis


## Get best pick from current analysis
func get_best_pick() -> Dictionary:
	return _current_analysis.get("best_pick", {})


## Get worst pick from current analysis
func get_worst_pick() -> Dictionary:
	return _current_analysis.get("worst_pick", {})
