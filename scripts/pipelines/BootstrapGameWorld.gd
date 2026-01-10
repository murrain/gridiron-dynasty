## Multi-year world orchestrator that simulates HS → College → NFL progression.
## Runs AdvanceWorldYear for N years to populate all league levels.
extends Node
class_name BootstrapGameWorld

const ConfigService = preload("res://autoloads/Config.gd")
const Rand = preload("res://autoloads/Rand.gd")
const AdvanceWorldYear = preload("res://scripts/pipelines/AdvanceWorldYear.gd")

@export var years_to_simulate: int = 20

var _config_instance: Node = null

## Main entry point: simulates years_to_simulate years ending at configured start_year.
## Returns: Dictionary with years_simulated, start_year, first_year, world_state, and summary.
##
## RNG Usage: Calls _resolve_year_seed() for each year, which uses Rand.splitmix64().
## Determinism: Same base_seed produces identical world_state across runs.
func run(base_seed: int = 0) -> Dictionary:
	# 1. Load config
	var config := _get_config()
	var main_cfg: Dictionary = config.get_config("main")
	var start_year := int(main_cfg.get("starting_year", 2025))
	var seed := base_seed if base_seed != 0 else int(main_cfg.get("random_seed", 0))

	# 2. Initialize empty world_state
	var world_state: Dictionary = {}

	# 3. Create AdvanceWorldYear instance
	var advance := AdvanceWorldYear.new()

	# 4. Calculate year range (simulate years_to_simulate years ending at start_year)
	var first_year := start_year - years_to_simulate + 1

	# 5. Simulate each year
	for year in range(first_year, start_year + 1):
		var year_seed := _resolve_year_seed(seed, year)
		var result := advance.run(world_state, year, year_seed)
		# Extract updated world_state from result
		world_state = result.get("world_state", world_state)
		# Log progress for debugging
		_log_year_progress(year, world_state)

	# 6. Return comprehensive summary
	return {
		"years_simulated": years_to_simulate,
		"start_year": start_year,
		"first_year": first_year,
		"world_state": world_state,
		"summary": _build_summary(world_state)
	}

## Derives a deterministic year seed from base seed and year.
## RNG Usage: Uses Rand.splitmix64() to mix base_seed with year.
func _resolve_year_seed(base_seed: int, year: int) -> int:
	if base_seed != 0:
		return Rand.splitmix64(base_seed ^ year)
	return Rand.splitmix64(year)

## Builds summary statistics from world_state.
## Counts entities across all league levels.
func _build_summary(world_state: Dictionary) -> Dictionary:
	return {
		"hs_schools": _count_array(world_state, "hs_schools"),
		"hs_players": _count_array(world_state, "hs_players"),
		"colleges": _count_array(world_state, "colleges"),
		"college_players": _count_college_players(world_state),
		"nfl_teams": _count_array(world_state, "nfl_teams"),
		"nfl_players": _count_nfl_players(world_state),
		"retired_players": _count_array(world_state, "retired_players"),
		"draft_pool_years": _count_draft_pool_years(world_state)
	}

func _count_array(state: Dictionary, key: String) -> int:
	return (state.get(key, []) as Array).size()

func _count_college_players(state: Dictionary) -> int:
	var rosters: Dictionary = state.get("college_rosters", {})
	var total := 0
	for college_id in rosters.keys():
		var roster: Dictionary = rosters[college_id]
		var players: Array = roster.get("players", [])
		total += players.size()
	return total

func _count_nfl_players(state: Dictionary) -> int:
	var rosters: Dictionary = state.get("nfl_rosters", {})
	var total := 0
	for team_id in rosters.keys():
		var roster_data = rosters[team_id]
		if roster_data is Array:
			total += (roster_data as Array).size()
		elif roster_data is Dictionary:
			var players: Array = (roster_data as Dictionary).get("players", [])
			total += players.size()
	return total

func _count_draft_pool_years(state: Dictionary) -> int:
	var draft_pool: Dictionary = state.get("draft_pool", {})
	return draft_pool.keys().size()

## Logs per-year progress for debugging and observability.
func _log_year_progress(year: int, world_state: Dictionary) -> void:
	var hs := _count_array(world_state, "hs_players")
	var college := _count_college_players(world_state)
	var nfl := _count_nfl_players(world_state)
	var retired := _count_array(world_state, "retired_players")
	print("BootstrapGameWorld: Year %d | HS=%d | College=%d | NFL=%d | Retired=%d" % [year, hs, college, nfl, retired])

## Returns config instance, creating it if needed.
func _get_config() -> Node:
	if _config_instance == null:
		_config_instance = ConfigService.new()
	return _config_instance
