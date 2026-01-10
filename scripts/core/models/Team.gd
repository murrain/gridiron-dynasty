@icon("res://icon.svg")
# res://scripts/core/models/Team.gd
extends Resource
class_name Team

@export var id: String = ""
@export var name: String = ""

# --- Cap accounting ---
# cap_limit is the team's specific cap limit (may be adjusted from league_cap)
# is_over_cap tracks whether cap_used exceeds cap_limit
@export var cap_limit: float = 0.0
@export var is_over_cap: bool = false
# league_cap should be supplied from league config or a future LeagueContainer.
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

func from_dict(d: Dictionary) -> void:
	id = String(d.get("id", id))
	name = String(d.get("name", name))

	var cap: Dictionary = d.get("cap", {})
	cap_limit = float(cap.get("cap_limit", cap_limit))
	cap_used = float(cap.get("cap_used", cap_used))
	cap_space = float(cap.get("cap_space", cap_space))
	is_over_cap = bool(d.get("is_over_cap", is_over_cap))
	league_cap = float(cap.get("league_cap", cap.get("cap_limit", league_cap)))

	var roster_payload: Dictionary = d.get("roster", {})
	if roster == null:
		roster = SportRoster.new()
	roster.from_dict(roster_payload)

	player_ids = (d.get("player_ids", player_ids) as Array).duplicate()

func to_dict() -> Dictionary:
	var roster_dict: Dictionary = {}
	if roster != null:
		roster_dict = roster.to_dict()
	return {
		"id": id,
		"name": name,
		"cap": {
			"league_cap": league_cap,
			"cap_used": cap_used,
			"cap_space": cap_space
		},
		"is_over_cap": is_over_cap,
		"roster": roster_dict,
		"player_ids": player_ids.duplicate()
	}
