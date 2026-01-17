## TeamSelectionScreen - Pre-draft team selection interface
##
## Displays all 32 NFL teams sorted by draft order, allowing the user
## to select which team they want to control during the draft.
##
## Features:
## - Team list showing city, name, and draft position (#1-32)
## - Detailed team info panel showing draft picks, coach, schemes
## - "Start Draft" button (enabled only when team is selected)
## - Sorted by draft order (worst record picks first)
##
## Usage:
##   var screen = TeamSelectionScreen.new()
##   screen.initialize(world_state, 2025)
##   screen.team_selected.connect(_on_team_selected)
##
extends Control
class_name TeamSelectionScreen

const Rand = preload("res://autoloads/Rand.gd")

## Emitted when user confirms team selection and starts draft
signal team_selected(team_id: String)

## Emitted when user cancels team selection
signal selection_cancelled()

## World state reference
var _world_state: Dictionary = {}
var _year: int = 2025

## Team data sorted by draft order
var _teams: Array = []
var _selected_team_id: String = ""
var _selected_index: int = -1

## Team lookup for fast access
var _team_by_id: Dictionary = {}

## UI References
@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var team_list: ItemList = $MarginContainer/VBoxContainer/MainContent/TeamListPanel/MarginContainer/TeamList
@onready var detail_panel: PanelContainer = $MarginContainer/VBoxContainer/MainContent/DetailPanel
@onready var team_name_label: Label = $MarginContainer/VBoxContainer/MainContent/DetailPanel/MarginContainer/VBoxContainer/TeamNameLabel
@onready var draft_position_label: Label = $MarginContainer/VBoxContainer/MainContent/DetailPanel/MarginContainer/VBoxContainer/DraftPositionLabel
@onready var division_label: Label = $MarginContainer/VBoxContainer/MainContent/DetailPanel/MarginContainer/VBoxContainer/DivisionLabel
@onready var coach_name_label: Label = $MarginContainer/VBoxContainer/MainContent/DetailPanel/MarginContainer/VBoxContainer/CoachSection/CoachNameLabel
@onready var offense_scheme_label: Label = $MarginContainer/VBoxContainer/MainContent/DetailPanel/MarginContainer/VBoxContainer/CoachSection/OffenseSchemeLabel
@onready var defense_scheme_label: Label = $MarginContainer/VBoxContainer/MainContent/DetailPanel/MarginContainer/VBoxContainer/CoachSection/DefenseSchemeLabel
@onready var draft_picks_label: Label = $MarginContainer/VBoxContainer/MainContent/DetailPanel/MarginContainer/VBoxContainer/StatsSection/DraftPicksLabel
@onready var roster_size_label: Label = $MarginContainer/VBoxContainer/MainContent/DetailPanel/MarginContainer/VBoxContainer/StatsSection/RosterSizeLabel
@onready var start_button: Button = $MarginContainer/VBoxContainer/ButtonBar/StartButton
@onready var random_button: Button = $MarginContainer/VBoxContainer/ButtonBar/RandomButton


func _ready() -> void:
	# Validate critical UI nodes
	if not team_list:
		push_error("[TeamSelectionScreen] team_list node not found - UI will not function")
		return

	if not start_button:
		push_error("[TeamSelectionScreen] start_button node not found - cannot start draft")
		return

	# Connect signals
	team_list.item_selected.connect(_on_team_selected)

	if start_button:
		start_button.pressed.connect(_on_start_pressed)
		start_button.disabled = true

	if random_button:
		random_button.pressed.connect(_on_random_pressed)

	_clear_detail_panel()


## Initialize with world state and draft year
func initialize(world_state: Dictionary, year: int) -> void:
	_world_state = world_state
	_year = year

	# Update title
	if title_label:
		title_label.text = "Select Your Team - %d NFL Draft" % year

	# Load and sort teams by draft order
	_load_teams()


## Load teams from world state and sort by draft order
func _load_teams() -> void:
	var raw_teams: Array = _world_state.get("nfl_teams", [])
	if raw_teams.is_empty():
		push_warning("[TeamSelectionScreen] No NFL teams found in world_state")
		return

	# Build team lookup and collect teams with draft order
	_team_by_id.clear()
	_teams.clear()

	for team in raw_teams:
		var t: Dictionary = team
		var team_id := String(t.get("id", ""))
		if team_id.is_empty():
			continue

		_team_by_id[team_id] = t
		_teams.append(t)

	# Sort by draft order (ascending - worst record picks first)
	_teams.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("draft_order", 999)) < int(b.get("draft_order", 999))
	)

	_populate_team_list()


## Populate the team list with sorted teams
func _populate_team_list() -> void:
	if not team_list:
		return

	team_list.clear()

	for i in range(_teams.size()):
		var team: Dictionary = _teams[i]
		var city := String(team.get("city", ""))
		var name := String(team.get("name", "Unknown"))
		var draft_order := int(team.get("draft_order", i + 1))

		# Format: "#1 - City Name"
		var display_text := "#%d - %s %s" % [draft_order, city, name]
		var idx := team_list.add_item(display_text)

		# Store team_id in metadata for retrieval
		team_list.set_item_metadata(idx, String(team.get("id", "")))


## Handle team selection in the list
func _on_team_selected(index: int) -> void:
	if index < 0 or index >= _teams.size():
		return

	_selected_index = index
	var team: Dictionary = _teams[index]
	_selected_team_id = String(team.get("id", ""))

	_update_detail_panel(team)

	if start_button:
		start_button.disabled = false
		start_button.text = "Start Draft as %s %s" % [
			String(team.get("city", "")),
			String(team.get("name", ""))
		]


## Update the detail panel with selected team info
func _update_detail_panel(team: Dictionary) -> void:
	var city := String(team.get("city", ""))
	var name := String(team.get("name", "Unknown"))
	var team_id := String(team.get("id", ""))

	if team_name_label:
		team_name_label.text = "%s %s" % [city, name]

	if draft_position_label:
		var draft_order := int(team.get("draft_order", 0))
		draft_position_label.text = "Draft Position: #%d" % draft_order

	if division_label:
		var division := String(team.get("division", ""))
		var conference := String(team.get("conference", ""))
		division_label.text = "%s %s" % [conference, division]

	# Coach info
	var coach: Dictionary = team.get("coach", {})
	if coach_name_label:
		coach_name_label.text = "Coach: %s" % String(coach.get("name", "Unknown"))

	if offense_scheme_label:
		var scheme := String(team.get("offensive_scheme", coach.get("offensive_scheme", "")))
		offense_scheme_label.text = "Offense: %s" % _format_scheme(scheme)

	if defense_scheme_label:
		var scheme := String(team.get("defensive_scheme", coach.get("defensive_scheme", "")))
		defense_scheme_label.text = "Defense: %s" % _format_scheme(scheme)

	# Draft picks info
	if draft_picks_label:
		var picks_info := _get_team_draft_picks(team_id)
		draft_picks_label.text = "Draft Picks: %s" % picks_info

	# Roster size
	if roster_size_label:
		var rosters: Dictionary = _world_state.get("nfl_rosters", {})
		var roster: Dictionary = rosters.get(team_id, {})
		var players: Array = roster.get("players", [])
		roster_size_label.text = "Current Roster: %d players" % players.size()


## Get formatted draft picks info for a team
func _get_team_draft_picks(team_id: String) -> String:
	var ownership: Dictionary = _world_state.get("draft_pick_ownership", {})
	var year_ownership: Dictionary = ownership.get(_year, {})

	if year_ownership.is_empty():
		return "7 picks (standard)"

	# Count picks owned by this team
	var picks_by_round: Dictionary = {}
	var total_picks := 0

	for round_num in range(1, 8):  # Rounds 1-7
		var round_ownership: Dictionary = year_ownership.get(round_num, {})
		var round_picks := 0

		for original_team_id in round_ownership.keys():
			var owner_id := String(round_ownership.get(original_team_id, ""))
			if owner_id == team_id:
				round_picks += 1
				total_picks += 1

		if round_picks > 0:
			picks_by_round[round_num] = round_picks

	if total_picks == 0:
		return "7 picks (standard)"

	# Format the picks info
	var round_strs: Array = []
	for round_num in picks_by_round.keys():
		var count: int = picks_by_round[round_num]
		if count > 1:
			round_strs.append("R%d: %d" % [round_num, count])
		else:
			round_strs.append("R%d" % round_num)

	return "%d picks (%s)" % [total_picks, ", ".join(round_strs)]


## Format scheme name for display (snake_case to Title Case)
func _format_scheme(scheme: String) -> String:
	if scheme.is_empty():
		return "Unknown"
	return scheme.replace("_", " ").capitalize()


## Clear the detail panel to initial state
func _clear_detail_panel() -> void:
	if team_name_label:
		team_name_label.text = "Select a Team"

	if draft_position_label:
		draft_position_label.text = "Draft Position: -"

	if division_label:
		division_label.text = ""

	if coach_name_label:
		coach_name_label.text = "Coach: -"

	if offense_scheme_label:
		offense_scheme_label.text = "Offense: -"

	if defense_scheme_label:
		defense_scheme_label.text = "Defense: -"

	if draft_picks_label:
		draft_picks_label.text = "Draft Picks: -"

	if roster_size_label:
		roster_size_label.text = "Current Roster: -"


## Handle Start Draft button press
func _on_start_pressed() -> void:
	if _selected_team_id.is_empty():
		push_warning("[TeamSelectionScreen] No team selected")
		return

	team_selected.emit(_selected_team_id)


## Handle Random button press
## Seeds RNG deterministically from world state creation seed for testability
## Uses a counter stored in world state to ensure different selections on repeated
## clicks while maintaining determinism for replay systems.
func _on_random_pressed() -> void:
	if _teams.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	# Seed from world state creation seed XOR with magic number for team selection
	# Magic: 0x7EAB5E1 = "TEAM SEL" (team selection)
	var creation_seed := int(_world_state.get("creation_seed", 0))

	# Get or initialize the deterministic selection counter
	# This replaces the previous time-based component to maintain replay determinism
	var selection_counter := int(_world_state.get("random_team_selection_count", 0))
	# Increment counter for next use
	_world_state["random_team_selection_count"] = selection_counter + 1

	# Seed using only deterministic values
	var seed := (creation_seed ^ 0x7EAB5E1) ^ selection_counter

	# Use splitmix64 from Rand autoload for better mixing
	rng.seed = Rand.splitmix64(seed)

	var random_index := rng.randi_range(0, _teams.size() - 1)

	team_list.select(random_index)
	_on_team_selected(random_index)


## Get the currently selected team ID
func get_selected_team_id() -> String:
	return _selected_team_id


## Get the currently selected team data
func get_selected_team() -> Dictionary:
	if _selected_index < 0 or _selected_index >= _teams.size():
		return {}
	return _teams[_selected_index]
