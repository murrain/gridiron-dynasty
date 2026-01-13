@icon("res://icon.svg")
# res://scripts/core/models/Team.gd
extends Resource
class_name Team

const SportRoster = preload("res://scripts/core/models/Roster.gd")

@export var id: String = ""
@export var name: String = ""

# --- Scheme preferences ---
@export var offensive_scheme: String = "pro_style"
@export var defensive_scheme: String = "cover_2"

# --- Cap accounting ---
# cap_limit = max allowed cap space
# league_cap should be supplied from league config or a future LeagueContainer.
@export var cap_limit: float = 0.0
@export var is_over_cap: bool = false
@export var league_cap: float = 0.0
@export var roster: SportRoster = SportRoster.new()

# Derived cap values (do not persist; compute from roster + league config).
# cap_used = sum of cap-relevant contract fields for non-exempt roster entries.
# cap_space = league_cap - cap_used.
var cap_used: float:
	get:
		if roster == null:
			return 0.0
		return roster.get_cap_used()

var cap_space: float:
	get:
		return league_cap - cap_used

# Roster scaffolding
@export var player_ids: Array[String] = []

# --- Scouting state ---
# Team-specific scouting data: player_id -> scouting_report_dict
# See ScoutingResourceManager for report schema
@export var scouting_data: Dictionary = {}

# Scouting resource budget for this team
# - annual_hours: Total hours allocated per year (from league tier)
# - spent_hours: Hours used this year (reset in AdvanceWorldYear)
@export var scouting_budget: Dictionary = {
	"annual_hours": 8000,  # Default NFL tier, set from league config
	"spent_hours": 0
}

func from_dict(d: Dictionary) -> void:
	id = String(d.get("id", id))
	name = String(d.get("name", name))

	# Scheme preferences
	offensive_scheme = String(d.get("offensive_scheme", offensive_scheme))
	defensive_scheme = String(d.get("defensive_scheme", defensive_scheme))

	var cap: Dictionary = d.get("cap", {})
	cap_limit = float(cap.get("cap_limit", cap_limit))
	# cap_used and cap_space are computed properties, not loaded
	is_over_cap = bool(d.get("is_over_cap", is_over_cap))
	league_cap = float(cap.get("league_cap", cap.get("cap_limit", league_cap)))

	var roster_payload: Dictionary = d.get("roster", {})
	if roster == null:
		roster = SportRoster.new()
	roster.from_dict(roster_payload)

	player_ids = (d.get("player_ids", player_ids) as Array).duplicate()

	# Scouting state
	scouting_data = (d.get("scouting_data", scouting_data) as Dictionary).duplicate(true)
	var budget_data: Dictionary = d.get("scouting_budget", {}) as Dictionary
	if not budget_data.is_empty():
		scouting_budget = budget_data.duplicate(true)

func to_dict() -> Dictionary:
	var roster_dict: Dictionary = {}
	if roster != null:
		roster_dict = roster.to_dict()
	return {
		"id": id,
		"name": name,
		"offensive_scheme": offensive_scheme,
		"defensive_scheme": defensive_scheme,
		"cap": {
			"league_cap": league_cap,
			"cap_used": cap_used,
			"cap_space": cap_space
		},
		"is_over_cap": is_over_cap,
		"roster": roster_dict,
		"player_ids": player_ids.duplicate(),
		"scouting_data": scouting_data.duplicate(true),
		"scouting_budget": scouting_budget.duplicate(true)
	}
