extends RefCounted
class_name CapValidationFlow

const CapAccounting = preload("res://scripts/core/finance/CapAccounting.gd")

# Cap validation is anchored to a dedicated calendar phase for traceability.
# Determinism: no RNG use, ordering follows the input team array.
const DEFAULT_PHASE_ID := "cap_validation"

static func run(
	world_state: Dictionary,
	year: int,
	phase_id: String,
	league_cap_limit: float
) -> Dictionary:
	var teams: Array = world_state.get("teams", []) as Array
	var team_rosters: Dictionary = world_state.get("team_rosters", {}) as Dictionary
	var team_results: Array = []
	var over_cap: Array = []

	for i in range(teams.size()):
		var team_entry := teams[i]
		var team: Dictionary = team_entry as Dictionary
		if team.is_empty():
			continue
		var team_id := String(team.get("id", ""))
		if team_id == "":
			team_id = "team_%d" % i
		var roster: Array = team_rosters.get(team_id, []) as Array
		var contract_rows := _contracts_from_roster(roster)
		var cap_used := CapAccounting.cap_used(contract_rows)
		var cap_limit := _resolve_cap_limit(team, league_cap_limit)
		var cap_space := cap_limit - cap_used
		var is_over := cap_limit > 0.0 and cap_used > cap_limit

		var cap_dict: Dictionary = team.get("cap", {}) as Dictionary
		cap_dict["cap_limit"] = cap_limit
		cap_dict["cap_used"] = cap_used
		cap_dict["cap_space"] = cap_space
		team["cap"] = cap_dict
		team["is_over_cap"] = is_over
		teams[i] = team

		team_results.append({
			"team_id": team_id,
			"cap_limit": cap_limit,
			"cap_used": cap_used,
			"cap_space": cap_space,
			"is_over_cap": is_over,
			"roster_size": roster.size()
		})
		if is_over:
			over_cap.append(team_id)

	world_state["teams"] = teams
	var flags: Dictionary = world_state.get("cap_flags", {}) as Dictionary
	flags[year] = {
		"over_cap": over_cap.duplicate(),
		"checked": team_results.size()
	}
	world_state["cap_flags"] = flags

	return {
		"phase_id": phase_id,
		"year": year,
		"cap_limit": league_cap_limit,
		"teams_checked": team_results.size(),
		"over_cap": over_cap,
		"team_results": team_results
	}

static func _contracts_from_roster(roster: Array) -> Array:
	var contracts: Array = []
	contracts.resize(roster.size())
	for i in range(roster.size()):
		var entry: Dictionary = roster[i] as Dictionary
		if entry.has("contract"):
			contracts[i] = entry.get("contract", {}) as Dictionary
		else:
			contracts[i] = entry
	return contracts

static func _resolve_cap_limit(team: Dictionary, league_cap_limit: float) -> float:
	var cap_dict: Dictionary = team.get("cap", {}) as Dictionary
	var team_cap := float(cap_dict.get("cap_limit", 0.0))
	if team_cap > 0.0:
		return team_cap
	return league_cap_limit
