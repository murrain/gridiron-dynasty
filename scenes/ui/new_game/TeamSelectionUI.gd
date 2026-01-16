## TeamSelectionUI - Interface for selecting a team to manage
##
## Displays a list of all 32 NFL teams with their coaches and lets
## the user select which team they want to manage. Shows:
## - Team name, city, division
## - Head coach name and schemes
## - Team overall rating
## - Number of draft picks
##
## Emits team_selected when user confirms their choice.
##
extends Control
class_name TeamSelectionUI

signal team_selected(team_id: String)
signal selection_cancelled()

## Team data array (set via set_teams)
var _teams: Array = []
var _selected_team_id: String = ""
var _selected_index: int = -1

## UI References
@onready var team_list: ItemList = $MarginContainer/VBoxContainer/MainContent/TeamListPanel/MarginContainer/TeamList
@onready var detail_panel: PanelContainer = $MarginContainer/VBoxContainer/MainContent/DetailPanel
@onready var team_name_label: Label = $MarginContainer/VBoxContainer/MainContent/DetailPanel/MarginContainer/VBoxContainer/TeamNameLabel
@onready var division_label: Label = $MarginContainer/VBoxContainer/MainContent/DetailPanel/MarginContainer/VBoxContainer/DivisionLabel
@onready var coach_name_label: Label = $MarginContainer/VBoxContainer/MainContent/DetailPanel/MarginContainer/VBoxContainer/CoachSection/CoachNameLabel
@onready var coach_ability_label: Label = $MarginContainer/VBoxContainer/MainContent/DetailPanel/MarginContainer/VBoxContainer/CoachSection/CoachAbilityLabel
@onready var offense_scheme_label: Label = $MarginContainer/VBoxContainer/MainContent/DetailPanel/MarginContainer/VBoxContainer/CoachSection/OffenseSchemeLabel
@onready var defense_scheme_label: Label = $MarginContainer/VBoxContainer/MainContent/DetailPanel/MarginContainer/VBoxContainer/CoachSection/DefenseSchemeLabel
@onready var team_overall_label: Label = $MarginContainer/VBoxContainer/MainContent/DetailPanel/MarginContainer/VBoxContainer/StatsSection/TeamOverallLabel
@onready var roster_size_label: Label = $MarginContainer/VBoxContainer/MainContent/DetailPanel/MarginContainer/VBoxContainer/StatsSection/RosterSizeLabel
@onready var draft_picks_label: Label = $MarginContainer/VBoxContainer/MainContent/DetailPanel/MarginContainer/VBoxContainer/StatsSection/DraftPicksLabel
@onready var select_button: Button = $MarginContainer/VBoxContainer/MainContent/DetailPanel/MarginContainer/VBoxContainer/SelectButton
@onready var random_button: Button = $MarginContainer/VBoxContainer/ButtonBar/RandomButton


func _ready() -> void:
	team_list.item_selected.connect(_on_team_selected)
	select_button.pressed.connect(_on_select_pressed)
	random_button.pressed.connect(_on_random_pressed)

	# Initial state
	select_button.disabled = true
	_clear_detail_panel()


## Set the list of available teams
func set_teams(teams: Array) -> void:
	_teams = teams
	_populate_team_list()


## Populate the item list with teams
func _populate_team_list() -> void:
	team_list.clear()

	for team in _teams:
		var t: Dictionary = team
		var name := String(t.get("name", "Unknown"))
		var city := String(t.get("city", ""))
		var overall := float(t.get("overall", 50.0))
		var picks := t.get("draft_picks", {}).get("total", 0)

		# Format: "City Name (OVR: 75, Picks: 7)"
		var display_text := "%s %s (OVR: %.0f, Picks: %d)" % [city, name, overall, picks]
		team_list.add_item(display_text)


## Handle team selection in list
func _on_team_selected(index: int) -> void:
	if index < 0 or index >= _teams.size():
		return

	_selected_index = index
	var team: Dictionary = _teams[index]
	_selected_team_id = String(team.get("id", ""))

	_update_detail_panel(team)
	select_button.disabled = false


## Update the detail panel with team info
func _update_detail_panel(team: Dictionary) -> void:
	var city := String(team.get("city", ""))
	var name := String(team.get("name", "Unknown"))
	team_name_label.text = "%s %s" % [city, name]

	var division := String(team.get("division", ""))
	var conference := String(team.get("conference", ""))
	division_label.text = "%s %s" % [conference, division]

	# Coach info
	var coach: Dictionary = team.get("coach", {})
	coach_name_label.text = "Coach: %s" % String(coach.get("name", "Unknown"))
	coach_ability_label.text = "Ability: %.0f" % float(coach.get("ability", 50.0))
	offense_scheme_label.text = "Offense: %s" % _format_scheme(coach.get("offensive_scheme", ""))
	defense_scheme_label.text = "Defense: %s" % _format_scheme(coach.get("defensive_scheme", ""))

	# Team stats
	team_overall_label.text = "Team Overall: %.0f" % float(team.get("overall", 50.0))
	roster_size_label.text = "Roster Size: %d" % int(team.get("roster_size", 0))

	var picks: Dictionary = team.get("draft_picks", {})
	var picks_str := "Draft Picks: %d total" % int(picks.get("total", 0))
	var by_round: Dictionary = picks.get("by_round", {})
	if not by_round.is_empty():
		var round_strs: Array = []
		for round_key in by_round.keys():
			var round_num := round_key.replace("round_", "Rd ")
			round_strs.append("%s: %d" % [round_num, by_round[round_key]])
		picks_str += " (%s)" % ", ".join(round_strs)
	draft_picks_label.text = picks_str


## Format scheme name for display
func _format_scheme(scheme: String) -> String:
	if scheme.is_empty():
		return "Unknown"
	# Convert snake_case to Title Case
	return scheme.replace("_", " ").capitalize()


## Clear the detail panel
func _clear_detail_panel() -> void:
	team_name_label.text = "Select a Team"
	division_label.text = ""
	coach_name_label.text = "Coach: -"
	coach_ability_label.text = "Ability: -"
	offense_scheme_label.text = "Offense: -"
	defense_scheme_label.text = "Defense: -"
	team_overall_label.text = "Team Overall: -"
	roster_size_label.text = "Roster Size: -"
	draft_picks_label.text = "Draft Picks: -"


## Handle select button press
func _on_select_pressed() -> void:
	if _selected_team_id.is_empty():
		return
	team_selected.emit(_selected_team_id)


## Handle random button press
func _on_random_pressed() -> void:
	if _teams.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var random_index := rng.randi_range(0, _teams.size() - 1)

	team_list.select(random_index)
	_on_team_selected(random_index)


## Get the currently selected team data
func get_selected_team() -> Dictionary:
	if _selected_index < 0 or _selected_index >= _teams.size():
		return {}
	return _teams[_selected_index]
