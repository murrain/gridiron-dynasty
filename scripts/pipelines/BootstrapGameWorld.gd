extends Node
class_name BootstrapGameWorld

const Config = preload("res://autoloads/Config.gd")
const Rand = preload("res://autoloads/Rand.gd")
const AdvanceWorldYear = preload("res://scripts/pipelines/AdvanceWorldYear.gd")

@export var years_to_simulate: int = 20

var _config_instance: Node = null

func _get_config() -> Node:
	if _config_instance == null:
		_config_instance = Config.new()
	return _config_instance

func run(base_seed: int = 0) -> Dictionary:
	var main_cfg: Dictionary = _get_config().get_config("main")
	var start_year := int(main_cfg.get("starting_year", 2025))
	var seed := base_seed if base_seed != 0 else int(main_cfg.get("random_seed", 0))

	var world_state: Dictionary = {}
	var advance := AdvanceWorldYear.new()

	var first_year := start_year - years_to_simulate + 1
	var year_results: Array = []

	for year in range(first_year, start_year + 1):
		var year_seed := _resolve_year_seed(seed, year)
		print("BootstrapGameWorld: simulating year %d (seed=%d)" % [year, year_seed])
		var result := advance.run(world_state, year, year_seed)
		world_state = result.get("world_state", world_state)
		year_results.append({
			"year": year,
			"year_seed": result.get("year_seed", year_seed),
			"phases": (result.get("phases", []) as Array).size()
		})

	return {
		"years_simulated": years_to_simulate,
		"start_year": start_year,
		"first_year": first_year,
		"base_seed": seed,
		"world_state": world_state,
		"year_results": year_results,
		"summary": _build_summary(world_state)
	}

func _resolve_year_seed(base_seed: int, year: int) -> int:
	if base_seed != 0:
		return Rand.splitmix64(base_seed ^ year)
	return Rand.splitmix64(year)

func _build_summary(world_state: Dictionary) -> Dictionary:
	return {
		"hs_schools": (world_state.get("hs_schools", []) as Array).size(),
		"hs_players": (world_state.get("hs_players", []) as Array).size(),
		"colleges": (world_state.get("colleges", []) as Array).size(),
		"college_rosters": _count_college_players(world_state),
		"nfl_teams": (world_state.get("nfl_teams", []) as Array).size(),
		"nfl_players": _count_nfl_players(world_state),
		"retired_players": (world_state.get("retired_players", []) as Array).size(),
		"draft_pool_years": _count_draft_pool_years(world_state),
		"free_agent_years": _count_free_agent_years(world_state)
	}

func _count_college_players(world_state: Dictionary) -> int:
	var rosters: Dictionary = world_state.get("college_rosters", {}) as Dictionary
	var count := 0
	for college_id in rosters.keys():
		var roster: Dictionary = rosters[college_id]
		var players: Array = roster.get("players", []) as Array
		count += players.size()
	return count

func _count_nfl_players(world_state: Dictionary) -> int:
	var rosters: Dictionary = world_state.get("nfl_rosters", {}) as Dictionary
	var count := 0
	for team_id in rosters.keys():
		var roster: Dictionary = rosters[team_id]
		var players: Array = roster.get("players", []) as Array
		count += players.size()
	return count

func _count_draft_pool_years(world_state: Dictionary) -> int:
	var pool: Dictionary = world_state.get("draft_pool", {}) as Dictionary
	return pool.size()

func _count_free_agent_years(world_state: Dictionary) -> int:
	var fa: Dictionary = world_state.get("free_agents", {}) as Dictionary
	return fa.size()
