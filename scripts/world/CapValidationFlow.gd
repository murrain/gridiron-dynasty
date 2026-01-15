extends RefCounted
class_name CapValidationFlow

const CapAccounting = preload("res://scripts/core/finance/CapAccounting.gd")
const Roster = preload("res://scripts/core/models/Roster.gd")

# Cap validation is anchored to a dedicated calendar phase for traceability.
# Determinism: no RNG use, ordering follows the input team array.
const DEFAULT_PHASE_ID := "cap_validation"

# Default roster limits (can be overridden via main_cfg)
const DEFAULT_ACTIVE_ROSTER_LIMIT := 53
const DEFAULT_PRACTICE_SQUAD_LIMIT := 16
const DEFAULT_IR_LIMIT := -1  # -1 = unlimited

static func run(
	world_state: Dictionary,
	year: int,
	phase_id: String,
	league_cap_limit: float,
	main_cfg: Dictionary = {}
) -> Dictionary:
	var teams: Array = world_state.get("teams", []) as Array
	var team_rosters: Dictionary = world_state.get("team_rosters", {}) as Dictionary
	var team_results: Array = []
	var over_cap: Array = []
	var roster_violations: Array = []  # Track teams with roster limit violations

	# Get roster limits from config
	var roster_limits := _get_roster_limits(main_cfg)

	for i in range(teams.size()):
		var team_entry = teams[i]
		if not (team_entry is Dictionary):
			continue
		var team: Dictionary = team_entry
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

		# Validate roster limits (Feature 5)
		var roster_validation := _validate_roster_limits(roster, roster_limits, team_id)
		var violations: Array = roster_validation["violations"]
		var has_roster_violations: bool = not violations.is_empty()

		var cap_dict: Dictionary = team.get("cap", {}) as Dictionary
		cap_dict["cap_limit"] = cap_limit
		cap_dict["cap_used"] = cap_used
		cap_dict["cap_space"] = cap_space
		team["cap"] = cap_dict
		team["is_over_cap"] = is_over
		team["roster_violations"] = roster_validation["violations"]
		teams[i] = team

		team_results.append({
			"team_id": team_id,
			"cap_limit": cap_limit,
			"cap_used": cap_used,
			"cap_space": cap_space,
			"is_over_cap": is_over,
			"roster_size": roster.size(),
			"active_count": roster_validation["active_count"],
			"practice_squad_count": roster_validation["practice_squad_count"],
			"ir_count": roster_validation["ir_count"],
			"roster_violations": roster_validation["violations"]
		})
		if is_over:
			over_cap.append(team_id)
		if has_roster_violations:
			roster_violations.append(team_id)

	world_state["teams"] = teams
	var flags: Dictionary = world_state.get("cap_flags", {}) as Dictionary
	flags[year] = {
		"over_cap": over_cap.duplicate(),
		"roster_violations": roster_violations.duplicate(),
		"checked": team_results.size()
	}
	world_state["cap_flags"] = flags

	return {
		"phase_id": phase_id,
		"year": year,
		"cap_limit": league_cap_limit,
		"teams_checked": team_results.size(),
		"over_cap": over_cap,
		"roster_violations": roster_violations,
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

## Get roster limits from main_cfg or use defaults
static func _get_roster_limits(main_cfg: Dictionary) -> Dictionary:
	var roster_cfg: Dictionary = main_cfg.get("roster_limits", {}) as Dictionary
	return {
		"active_limit": int(roster_cfg.get("active_limit", DEFAULT_ACTIVE_ROSTER_LIMIT)),
		"practice_squad_limit": int(roster_cfg.get("practice_squad_limit", DEFAULT_PRACTICE_SQUAD_LIMIT)),
		"ir_limit": int(roster_cfg.get("ir_limit", DEFAULT_IR_LIMIT))
	}

## Validate roster composition against limits
## Returns dictionary with counts and violations array
static func _validate_roster_limits(roster: Array, limits: Dictionary, team_id: String) -> Dictionary:
	var active_count := 0
	var practice_squad_count := 0
	var ir_count := 0
	var suspended_count := 0

	# Count players by status
	for entry in roster:
		var row: Dictionary = entry as Dictionary
		var status := String(row.get("status", "active"))
		match status:
			"active":
				active_count += 1
			"practice_squad":
				practice_squad_count += 1
			"ir":
				ir_count += 1
			"suspended":
				suspended_count += 1

	# Check violations
	var violations: Array = []
	var active_limit := int(limits.get("active_limit", DEFAULT_ACTIVE_ROSTER_LIMIT))
	var ps_limit := int(limits.get("practice_squad_limit", DEFAULT_PRACTICE_SQUAD_LIMIT))
	var ir_limit := int(limits.get("ir_limit", DEFAULT_IR_LIMIT))

	if active_limit > 0 and active_count > active_limit:
		violations.append({
			"type": "active_roster_exceeded",
			"team_id": team_id,
			"status": "active",
			"count": active_count,
			"limit": active_limit,
			"over_by": active_count - active_limit
		})

	if ps_limit > 0 and practice_squad_count > ps_limit:
		violations.append({
			"type": "practice_squad_exceeded",
			"team_id": team_id,
			"status": "practice_squad",
			"count": practice_squad_count,
			"limit": ps_limit,
			"over_by": practice_squad_count - ps_limit
		})

	if ir_limit > 0 and ir_count > ir_limit:
		violations.append({
			"type": "injured_reserve_exceeded",
			"team_id": team_id,
			"status": "injured_reserve",
			"count": ir_count,
			"limit": ir_limit,
			"over_by": ir_count - ir_limit
		})

	return {
		"active_count": active_count,
		"practice_squad_count": practice_squad_count,
		"ir_count": ir_count,
		"suspended_count": suspended_count,
		"violations": violations
	}
