## NewGameFlow - Bootstrap world and prepare for user's first draft
##
## This pipeline orchestrates the new game experience:
## 1. Generates 19 years of world history (players, teams, rosters)
## 2. Runs year 20 up to the draft phase (all pre-draft phases complete)
## 3. Returns world state ready for user to participate in the draft
##
## The user then selects their team and participates in the draft as
## the coach of that team.
##
## Usage:
##   var flow = NewGameFlow.new()
##   var result = flow.run(seed)
##   # result contains: world_state, available_teams, draft_pool, current_year
##
extends RefCounted
class_name NewGameFlow

const ConfigService = preload("res://autoloads/Config.gd")
const Rand = preload("res://autoloads/Rand.gd")
const AdvanceWorldYear = preload("res://scripts/pipelines/AdvanceWorldYear.gd")
const BootstrapGameWorld = preload("res://scripts/pipelines/BootstrapGameWorld.gd")
const NflDraft = preload("res://scripts/world/NflDraft.gd")

var _config_instance: Node = null

## Progress callback for UI updates
## Called with (phase_name: String, progress: float) where progress is 0.0-1.0
var progress_callback: Callable = Callable()

## Run the new game flow
##
## Parameters:
##   base_seed: Deterministic seed for world generation (0 = use config default)
##   years_of_history: Number of years to simulate before the user's first draft (default: 19)
##
## Returns:
##   Dictionary with:
##     - world_state: Complete world state ready for draft
##     - available_teams: Array of teams user can choose from
##     - draft_pool: Array of players available in the draft
##     - current_year: The year of the user's first draft
##     - summary: World generation summary statistics
func run(base_seed: int = 0, years_of_history: int = 19) -> Dictionary:
	var config := _get_config()
	var main_cfg: Dictionary = config.get_config("main")
	var start_year := int(main_cfg.get("starting_year", 2025))
	var seed := base_seed if base_seed != 0 else int(main_cfg.get("random_seed", 0))

	_report_progress("Initializing", 0.0)

	# Phase 1: Bootstrap world history (19 years by default)
	# This creates all the infrastructure: HS schools, colleges, NFL teams, rosters
	_report_progress("Generating world history", 0.05)

	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = years_of_history

	var bootstrap_result := bootstrap.run(seed)

	if bootstrap_result.is_empty() or not bootstrap_result.has("world_state"):
		push_error("[NewGameFlow] Bootstrap failed to produce world_state")
		return {"error": "Bootstrap failed"}

	var world_state: Dictionary = bootstrap_result["world_state"]
	var draft_year := start_year  # The year of the user's first draft

	_report_progress("Running pre-draft phases", 0.7)

	# Phase 2: Run year 20's pre-draft phases (up to but not including nfl_draft)
	# This prepares the draft pool for the user's participation
	var advance := AdvanceWorldYear.new()
	advance.set_bootstrap_mode(false)  # Full mode for the user's year

	var year_seed := _resolve_year_seed(seed, draft_year)

	# Run only the pre-draft phases
	var pre_draft_phases := [
		"hs_generation",
		"hs_assignment",
		"hs_season",
		"college_generation",
		"nfl_team_generation",
		"college_recruiting",
		"college_season",
		"draft_prep",
	]

	world_state = _run_phases(advance, world_state, draft_year, year_seed, pre_draft_phases)

	_report_progress("Preparing draft", 0.9)

	# Ensure draft pick ownership is initialized
	var teams: Array = world_state.get("nfl_teams", [])
	var league_cfg: Dictionary = config.get_config("world/league")
	var draft_cfg: Dictionary = league_cfg.get("draft", {})
	var rounds := int(draft_cfg.get("rounds", 7))

	if not world_state.has("draft_pick_ownership"):
		NflDraft.initialize_pick_ownership(world_state, teams, draft_year, rounds)

	# Build available teams list with coach info
	var available_teams := _build_team_list(world_state)

	# Get draft pool for this year
	var draft_pool_all: Dictionary = world_state.get("draft_pool", {})
	var draft_pool: Array = draft_pool_all.get(draft_year, [])

	_report_progress("Complete", 1.0)

	return {
		"world_state": world_state,
		"available_teams": available_teams,
		"draft_pool": draft_pool,
		"draft_pool_size": draft_pool.size(),
		"current_year": draft_year,
		"seed": seed,
		"summary": bootstrap_result.get("summary", {}),
	}


## Run specific phases for a year
func _run_phases(advance: AdvanceWorldYear, world_state: Dictionary, year: int, year_seed: int, phase_ids: Array) -> Dictionary:
	var config := _get_config()

	# Get the WorldCalendar phases to understand phase ordering
	var WorldCalendar = preload("res://scripts/world/WorldCalendar.gd")
	var calendar := WorldCalendar.new()
	var all_phases := calendar.phases_for_year(year, "world/calendar", config)

	# Build lookup of phase handlers (GDScript allows calling underscore methods)
	var handlers: Dictionary = advance._phase_handlers()

	for phase in all_phases:
		var phase_id := String(phase.get("phase_id", ""))

		# Only run phases in our list
		if phase_id not in phase_ids:
			continue

		# Use local _derive_seed implementation for clarity
		var phase_seed := _derive_seed(year_seed, phase_id, "phase")
		var handler: Callable = handlers.get(phase_id, Callable())

		if handler.is_valid():
			print("[NewGameFlow] Running phase: %s (seed: %d)" % [phase_id, phase_seed])
			handler.call(world_state, year, phase_seed, phase, year_seed)

	return world_state


## Derive a deterministic seed from year_seed, phase_id, and step_id
## Matches AdvanceWorldYear._derive_seed() implementation
func _derive_seed(year_seed: int, phase_id: String, step_id: String) -> int:
	var key := "%s:%s" % [phase_id, step_id]
	var hash := _fnv1a_64(key)
	return Rand.splitmix64(year_seed ^ hash)


## FNV-1a 64-bit hash implementation
## Matches AdvanceWorldYear._fnv1a_64() implementation
func _fnv1a_64(text: String) -> int:
	var hash: int = -3750763034362895579
	var prime: int = 1099511628211
	for b in text.to_utf8_buffer():
		hash = int(hash ^ b) & -1
		hash = int(hash * prime) & -1
	return hash


## Build list of available teams with coach info
func _build_team_list(world_state: Dictionary) -> Array:
	var teams: Array = world_state.get("nfl_teams", [])
	var rosters: Dictionary = world_state.get("nfl_rosters", {})
	var result: Array = []

	for team in teams:
		var t: Dictionary = team
		var team_id := String(t.get("id", ""))
		var roster: Dictionary = rosters.get(team_id, {})
		var players: Array = roster.get("players", [])

		# Calculate team overall (average of starters)
		var total_ovr := 0.0
		var count := 0
		for player in players:
			var p: Dictionary = player
			var ovr := float(p.get("composite_score", p.get("overall", 50.0)))
			total_ovr += ovr
			count += 1
		var avg_ovr := total_ovr / float(max(count, 1))

		# Get coach info
		var coach: Dictionary = t.get("coach", {})

		# Get draft picks for this team
		var ownership: Dictionary = world_state.get("draft_pick_ownership", {})
		var picks := _count_team_picks(ownership, team_id)

		result.append({
			"id": team_id,
			"name": String(t.get("name", team_id)),
			"city": String(t.get("city", "")),
			"abbreviation": String(t.get("abbreviation", team_id.to_upper().substr(0, 3))),
			"division": String(t.get("division", "")),
			"conference": String(t.get("conference", "")),
			"overall": avg_ovr,
			"roster_size": players.size(),
			"coach": {
				"name": "%s %s" % [coach.get("first_name", ""), coach.get("last_name", "")],
				"ability": float(coach.get("coaching_ability", 50.0)),
				"offensive_scheme": String(coach.get("offensive_scheme", "")),
				"defensive_scheme": String(coach.get("defensive_scheme", "")),
			},
			"draft_picks": picks,
		})

	# Sort by name for consistent display
	result.sort_custom(func(a, b):
		return String(a.get("name", "")) < String(b.get("name", ""))
	)

	return result


## Count draft picks owned by a team
func _count_team_picks(ownership: Dictionary, team_id: String) -> Dictionary:
	var picks := {"total": 0, "by_round": {}}

	for year in ownership.keys():
		var year_ownership: Dictionary = ownership[year]
		for round_num in year_ownership.keys():
			var round_ownership: Dictionary = year_ownership[round_num]
			for original_team in round_ownership.keys():
				if String(round_ownership[original_team]) == team_id:
					picks["total"] += 1
					var round_key := "round_%d" % round_num
					if not picks["by_round"].has(round_key):
						picks["by_round"][round_key] = 0
					picks["by_round"][round_key] += 1

	return picks


## Resolve year seed (matches BootstrapGameWorld pattern)
func _resolve_year_seed(base_seed: int, year: int) -> int:
	if base_seed != 0:
		return Rand.splitmix64(base_seed ^ year)
	return Rand.splitmix64(year)


## Report progress to callback if set
func _report_progress(phase_name: String, progress: float) -> void:
	if progress_callback.is_valid():
		progress_callback.call(phase_name, progress)
	print("[NewGameFlow] %s (%.0f%%)" % [phase_name, progress * 100])


## Get config instance
func _get_config() -> Node:
	if _config_instance == null:
		_config_instance = ConfigService.new()
	return _config_instance
