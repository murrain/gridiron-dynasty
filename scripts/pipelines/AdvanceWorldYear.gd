extends Node
class_name AdvanceWorldYear

const Config = preload("res://autoloads/Config.gd")
const Rand = preload("res://autoloads/Rand.gd")
const WorldCalendar = preload("res://scripts/world/WorldCalendar.gd")
const HighSchoolGenerator = preload("res://scripts/world/HighSchoolGenerator.gd")
const HighSchoolAssignment = preload("res://scripts/world/HighSchoolAssignment.gd")
const HighSchoolSeason = preload("res://scripts/world/HighSchoolSeason.gd")
const HighSchoolBackground = preload("res://scripts/world/HighSchoolBackground.gd")
const CollegeGenerator = preload("res://scripts/world/CollegeGenerator.gd")
const CollegeRecruiting = preload("res://scripts/pipelines/CollegeRecruiting.gd")
const CollegeSeason = preload("res://scripts/world/CollegeSeason.gd")
const NflTeamGenerator = preload("res://scripts/world/NflTeamGenerator.gd")
const NflDraft = preload("res://scripts/world/NflDraft.gd")
const NflSeason = preload("res://scripts/world/NflSeason.gd")
const DraftClassGenerator = preload("res://scripts/generation/DraftClassGenerator.gd")
const ValuationFlow = preload("res://scripts/world/ValuationFlow.gd")
const CapValidationFlow = preload("res://scripts/world/CapValidationFlow.gd")
const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")
const FreeAgency = preload("res://scripts/world/FreeAgency.gd")

## Cached config instance for performance optimization.
## The Config object is read-only during simulation and contains no mutable state
## that affects determinism. Caching eliminates redundant file I/O across phases.
## This is safe because:
## 1. Config is never modified during simulation
## 2. All phase handlers receive identical config data
## 3. Tests can clear this via set_bootstrap_mode() or create fresh instances
var _config_instance: Node = null

var _bootstrap_mode: bool = false

## Returns the cached config instance, creating it on first access.
## Safe for caching because Config is read-only during simulation.
func _get_config() -> Node:
	if _config_instance == null:
		_config_instance = Config.new()
	return _config_instance

## Enable or disable bootstrap mode.
## When enabled, PlayerLifecycle operations will skip development report generation
## to reduce memory usage during world initialization.
func set_bootstrap_mode(enabled: bool) -> void:
	_bootstrap_mode = enabled

## Returns lifecycle options based on current bootstrap mode.
## Used to pass skip_reports flag to season handlers.
func _lifecycle_options() -> Dictionary:
	return {"skip_reports": _bootstrap_mode}

## Executes all phases for a given year in the world simulation.
##
## Parameters:
##   world_state: Mutable state dictionary tracking all entities across leagues
##   year: The simulation year to execute
##   year_seed: Deterministic seed for this year (0 = randomize)
##   capture_timing: If true, records per-phase timing in microseconds (default: false)
##
## Returns:
##   Dictionary containing:
##     - year: The simulated year
##     - year_seed: The resolved seed used (may differ from input if randomized)
##     - year_seed_input: The original seed parameter
##     - phases: Array of phase results with seed lineage
##     - world_state: Updated world state
##     - timing: (Optional) Dictionary of phase_id -> microseconds if capture_timing=true
##
## RNG Usage: Each phase receives a deterministic seed derived from year_seed.
## Determinism: capture_timing does NOT alter RNG usage or phase execution order.
func run(world_state: Dictionary, year: int, year_seed: int, capture_timing: bool = false) -> Dictionary:
	var calendar := WorldCalendar.new()
	var config := _get_config()
	var phases := calendar.phases_for_year(year, "world/calendar", config)
	var results: Array = []
	var state := world_state if world_state != null else {}

	var rng := RandomNumberGenerator.new()
	var resolved_year_seed := year_seed
	if year_seed != 0:
		rng.seed = year_seed
	else:
		rng.randomize()
		resolved_year_seed = int(rng.randi())

	# Timing capture dictionary (only populated if capture_timing=true)
	var phase_timings := {}

	var handlers := _phase_handlers()
	for phase in phases:
		var phase_id := String(phase.get("phase_id", ""))
		var phase_seed := _derive_seed(resolved_year_seed, phase_id, "phase")

		# Start timing capture (does NOT consume RNG)
		var start_time: int = Time.get_ticks_usec()

		_log_phase_start(year, phase_id, phase_seed)
		var handler: Callable = handlers.get(phase_id, _handle_unknown_phase)
		var output: Dictionary = handler.call(state, year, phase_seed, phase, resolved_year_seed)
		_log_phase_end(year, phase_id, phase_seed)

		# End timing capture (does NOT consume RNG)
		var elapsed_usec: int = Time.get_ticks_usec() - start_time
		var elapsed_ms: float = elapsed_usec / 1000.0

		phase_timings[phase_id] = elapsed_ms
		_log_phase_summary(phase_id, year, output, elapsed_ms)

		# Legacy capture_timing support (store microseconds if requested)
		if capture_timing:
			phase_timings[phase_id] = elapsed_usec

		results.append({
			"phase_id": phase_id,
			"seed": phase_seed,
			"seed_lineage": {
				"year_seed": resolved_year_seed,
				"phase_index": int(phase.get("index", 0)),
				"phase_id": phase_id
			},
			"output": output
		})

	# Log timing summary
	print("[AdvanceWorldYear] Year %d timing summary:" % year)
	var total_ms: float = 0.0
	for pid in phase_timings.keys():
		var ms: float = phase_timings[pid] if not capture_timing else phase_timings[pid] / 1000.0
		total_ms += ms
		if ms > 100.0:  # Only log phases >100ms to reduce noise
			print("  %s: %.1fms" % [pid, ms])
	print("  TOTAL: %.1fms" % total_ms)

	var result := {
		"year": year,
		"year_seed": resolved_year_seed,
		"year_seed_input": year_seed,
		"phases": results,
		"world_state": state
	}

	# Only include timing field if capture_timing was enabled
	if capture_timing:
		result["timing"] = phase_timings

	return result

func _phase_handlers() -> Dictionary:
	return {
		"hs_generation": Callable(self, "_handle_hs_generation"),
		"hs_assignment": Callable(self, "_handle_hs_assignment"),
		"hs_season": Callable(self, "_handle_hs_season"),
		"college_generation": Callable(self, "_handle_college_generation"),
		"nfl_team_generation": Callable(self, "_handle_nfl_team_generation"),
		"college_recruiting": Callable(self, "_handle_college_recruiting"),
		"college_season": Callable(self, "_handle_college_season"),
		"draft_prep": Callable(self, "_handle_draft_prep"),
		"nfl_draft": Callable(self, "_handle_nfl_draft"),
		"nfl_free_agency": Callable(self, "_handle_nfl_free_agency"),
		"cap_validation": Callable(self, "_handle_cap_validation"),
		"nfl_season": Callable(self, "_handle_nfl_season")
	}

func _handle_hs_generation(
	world_state: Dictionary,
	year: int,
	_seed: int,
	phase: Dictionary,
	year_seed: int
) -> Dictionary:
	var phase_id := String(phase.get("phase_id", ""))
	var hs_cfg: Dictionary = _get_config().get_config("world/high_schools")
	var step_seeds := {
		"hs_school_gen": _derive_seed(year_seed, phase_id, "hs_school_gen"),
		"hs_player_gen": _derive_seed(year_seed, phase_id, "hs_player_gen"),
		"hs_player_meta": _derive_seed(year_seed, phase_id, "hs_player_meta"),
		"hs_background": _derive_seed(year_seed, phase_id, "hs_background")
	}
	for step_id in step_seeds.keys():
		_log_step_seed(year, phase_id, step_id, int(step_seeds[step_id]))

	var schools: Array = world_state.get("hs_schools", []) as Array
	if schools.is_empty():
		var school_gen := HighSchoolGenerator.new()
		var config := _get_config()
		var generated := school_gen.generate(step_seeds["hs_school_gen"], "world/high_schools", config)
		schools = generated.get("schools", []) as Array
		world_state["hs_schools"] = schools

	world_state["hs_school_index"] = _school_index(schools)

	var generator := DraftClassGenerator.new()
	var players := generator.generate_for_year(year, step_seeds["hs_player_gen"])
	_apply_hs_player_fields(players, year, hs_cfg, step_seeds["hs_player_meta"])

	# Generate HS background for each player (region, tier, stars, hype)
	var bg_stats := _apply_hs_backgrounds(players, step_seeds["hs_background"])

	var hs_players: Array = world_state.get("hs_players", []) as Array
	hs_players.append_array(players)
	world_state["hs_players"] = hs_players

	return {
		"class_year": year,
		"count": players.size(),
		"schools": schools.size(),
		"step_seeds": step_seeds,
		"background_stats": bg_stats
	}

func _handle_hs_assignment(
	world_state: Dictionary,
	year: int,
	_seed: int,
	phase: Dictionary,
	year_seed: int
) -> Dictionary:
	var phase_id := String(phase.get("phase_id", ""))
	var hs_cfg: Dictionary = _get_config().get_config("world/high_schools")
	var step_seed := _derive_seed(year_seed, phase_id, "hs_assignment")
	_log_step_seed(year, phase_id, "hs_assignment", step_seed)

	var hs_players: Array = world_state.get("hs_players", []) as Array
	var hs_schools: Array = world_state.get("hs_schools", []) as Array
	var assignment := HighSchoolAssignment.new()
	var output := assignment.assign(hs_players, hs_schools, hs_cfg, step_seed)
	world_state["hs_players"] = output.get("players", hs_players) as Array
	world_state["hs_schools"] = hs_schools
	world_state["hs_school_index"] = _school_index(hs_schools)

	return {
		"year": year,
		"count": hs_players.size(),
		"assigned": int(output.get("assigned", 0)),
		"unassigned": int(output.get("unassigned", 0)),
		"step_seeds": {"hs_assignment": step_seed}
	}

func _handle_hs_season(
	world_state: Dictionary,
	year: int,
	_seed: int,
	phase: Dictionary,
	year_seed: int
) -> Dictionary:
	var phase_id := String(phase.get("phase_id", ""))
	var step_seed := _derive_seed(year_seed, phase_id, "hs_season")
	_log_step_seed(year, phase_id, "hs_season", step_seed)

	var hs_cfg: Dictionary = _get_config().get_config("world/high_schools")
	var main_cfg: Dictionary = _get_config().get_config("main")
	var positions_cfg: Dictionary = _get_config().get_config("positions")
	var stats_cfg: Dictionary = _get_config().get_config("stats")

	var hs_players: Array = world_state.get("hs_players", []) as Array
	var hs_schools: Array = world_state.get("hs_schools", []) as Array
	var season := HighSchoolSeason.new()
	var output := season.run(hs_players, hs_schools, positions_cfg, main_cfg, stats_cfg, hs_cfg, step_seed, year, _lifecycle_options())

	var active: Array = output.get("players", []) as Array
	var graduates: Array = output.get("graduates", []) as Array
	world_state["hs_players"] = active

	# Filter graduates to only college-eligible players
	var filtered_recruits := _filter_college_eligible(graduates, positions_cfg, main_cfg, hs_cfg)

	var recruit_pool: Dictionary = world_state.get("hs_recruit_pool", {}) as Dictionary
	var profiles := _build_recruit_profiles(filtered_recruits, year)
	recruit_pool[year] = profiles
	world_state["hs_recruit_pool"] = recruit_pool

	return {
		"year": year,
		"count": active.size(),
		"graduates": graduates.size(),
		"college_eligible": filtered_recruits.size(),
		"ineligible": graduates.size() - filtered_recruits.size(),
		"transition_count": (output.get("transitions", []) as Array).size(),
		"recruit_profiles": profiles.size(),
		"step_seeds": {"hs_season": step_seed}
	}

func _handle_college_generation(
	world_state: Dictionary,
	year: int,
	_seed: int,
	phase: Dictionary,
	year_seed: int
) -> Dictionary:
	var phase_id := String(phase.get("phase_id", ""))
	var step_seed := _derive_seed(year_seed, phase_id, "college_generation")
	_log_step_seed(year, phase_id, "college_generation", step_seed)

	var colleges: Array = world_state.get("colleges", []) as Array
	if colleges.is_empty():
		var generator := CollegeGenerator.new()
		var generated := generator.generate(step_seed)
		colleges = generated.get("colleges", []) as Array
		world_state["colleges"] = colleges

	return {
		"year": year,
		"count": colleges.size(),
		"step_seeds": {"college_generation": step_seed}
	}

func _handle_nfl_team_generation(
	world_state: Dictionary,
	year: int,
	_seed: int,
	phase: Dictionary,
	year_seed: int
) -> Dictionary:
	var phase_id := String(phase.get("phase_id", ""))
	var step_seed := _derive_seed(year_seed, phase_id, "nfl_team_generation")
	_log_step_seed(year, phase_id, "nfl_team_generation", step_seed)

	var teams: Array = world_state.get("nfl_teams", []) as Array
	if not teams.is_empty():
		return {
			"year": year,
			"count": teams.size(),
			"cached": true,
			"step_seeds": {"nfl_team_generation": step_seed}
		}

	var generator := NflTeamGenerator.new()
	var result := generator.generate(step_seed)
	teams = result.get("teams", []) as Array
	world_state["nfl_teams"] = teams
	# Only initialize rosters if they don't exist (preserve drafted players!)
	if not world_state.has("nfl_rosters"):
		world_state["nfl_rosters"] = {}

	return {
		"year": year,
		"count": teams.size(),
		"step_seeds": {"nfl_team_generation": step_seed}
	}

func _handle_college_recruiting(
	world_state: Dictionary,
	year: int,
	_seed: int,
	phase: Dictionary,
	year_seed: int
) -> Dictionary:
	var phase_id := String(phase.get("phase_id", ""))
	var step_seed := _derive_seed(year_seed, phase_id, "college_recruiting")
	_log_step_seed(year, phase_id, "college_recruiting", step_seed)

	var colleges: Array = world_state.get("colleges", []) as Array
	var recruit_pool: Dictionary = world_state.get("hs_recruit_pool", {}) as Dictionary
	var recruits: Array = recruit_pool.get(year, []) as Array

	if colleges.is_empty() or recruits.is_empty():
		return {
			"year": year,
			"offers": 0,
			"commitments": 0,
			"uncommitted": recruits.size(),
			"step_seeds": {"college_recruiting": step_seed}
		}

	var main_cfg: Dictionary = _get_config().get_config("main")
	var positions_cfg: Dictionary = _get_config().get_config("positions")
	var stats_cfg: Dictionary = _get_config().get_config("stats")
	var scouts_cfg: Dictionary = _get_config().get_config("scouts")
	var colleges_cfg: Dictionary = _get_config().get_config("world/colleges")

	var pipeline := CollegeRecruiting.new()
	var output := pipeline.run(
		recruits,
		colleges,
		colleges_cfg,
		positions_cfg,
		stats_cfg,
		main_cfg.get("class_rules", {}),
		scouts_cfg,
		step_seed,
		year
	)

	var commitments: Array = output.get("commitments", []) as Array
	var college_commitments: Dictionary = world_state.get("college_commitments", {}) as Dictionary
	college_commitments[year] = commitments
	world_state["college_commitments"] = college_commitments
	world_state["college_classes"] = output.get("college_classes", {})

	# A1: Initialize college rosters from commitments
	_initialize_college_rosters(world_state, year, commitments, recruits)

	return {
		"year": year,
		"offers": int(output.get("offers", 0)),
		"commitments": commitments.size(),
		"uncommitted": (output.get("uncommitted", []) as Array).size(),
		"step_seeds": {"college_recruiting": step_seed}
	}

func _handle_college_season(
	world_state: Dictionary,
	year: int,
	_seed: int,
	phase: Dictionary,
	year_seed: int
) -> Dictionary:
	var phase_id := String(phase.get("phase_id", ""))
	var step_seed := _derive_seed(year_seed, phase_id, "college_season")
	_log_step_seed(year, phase_id, "college_season", step_seed)

	var season := CollegeSeason.new()
	var colleges_cfg: Dictionary = _get_config().get_config("world/colleges")
	var positions_cfg: Dictionary = _get_config().get_config("positions")
	var main_cfg: Dictionary = _get_config().get_config("main")
	var stats_cfg: Dictionary = _get_config().get_config("stats")
	return season.run(world_state, year, step_seed, colleges_cfg, positions_cfg, main_cfg, stats_cfg, _lifecycle_options())

func _handle_draft_prep(
	world_state: Dictionary,
	year: int,
	_seed: int,
	phase: Dictionary,
	year_seed: int
) -> Dictionary:
	var phase_id := String(phase.get("phase_id", ""))
	var step_seed := _derive_seed(year_seed, phase_id, "valuation")
	_log_step_seed(year, phase_id, "valuation", step_seed)

	var output := ValuationFlow.run(world_state, year, phase_id, step_seed)
	var snapshots: Dictionary = world_state.get("valuation_snapshots", {}) as Dictionary
	snapshots[year] = output
	world_state["valuation_snapshots"] = snapshots

	return output

func _handle_cap_validation(
	world_state: Dictionary,
	year: int,
	_seed: int,
	phase: Dictionary,
	_year_seed: int
) -> Dictionary:
	var phase_id := String(phase.get("phase_id", ""))
	var league_cfg: Dictionary = _get_config().get_config("world/league")
	var league_state: Dictionary = world_state.get("league", {}) as Dictionary
	var cap_limit := float(league_state.get("cap_limit", league_cfg.get("cap_limit", 0.0)))

	return CapValidationFlow.run(world_state, year, phase_id, cap_limit)

func _handle_nfl_draft(
	world_state: Dictionary,
	year: int,
	_seed: int,
	phase: Dictionary,
	year_seed: int
) -> Dictionary:
	var phase_id := String(phase.get("phase_id", ""))
	var step_seed := _derive_seed(year_seed, phase_id, "nfl_draft")
	_log_step_seed(year, phase_id, "nfl_draft", step_seed)

	var league_cfg: Dictionary = _get_config().get_config("world/league")
	var positions_cfg: Dictionary = _get_config().get_config("positions")
	var stats_cfg: Dictionary = _get_config().get_config("stats")
	var scouts_cfg: Dictionary = _get_config().get_config("scouts")
	var main_cfg: Dictionary = _get_config().get_config("main")

	var draft := NflDraft.new()
	return draft.run(world_state, year, step_seed, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

func _handle_nfl_free_agency(
	world_state: Dictionary,
	year: int,
	_seed: int,
	phase: Dictionary,
	year_seed: int
) -> Dictionary:
	var phase_id := String(phase.get("phase_id", ""))
	var step_seed := _derive_seed(year_seed, phase_id, "nfl_free_agency")
	_log_step_seed(year, phase_id, "nfl_free_agency", step_seed)

	var league_cfg: Dictionary = _get_config().get_config("world/league")
	var positions_cfg: Dictionary = _get_config().get_config("positions")
	var main_cfg: Dictionary = _get_config().get_config("main")
	var stats_cfg: Dictionary = _get_config().get_config("stats")

	# Run free agency simulation
	# RNG PATTERN: FreeAgency.run_free_agency() uses step_seed for all deterministic operations
	# Expected RNG calls: ~7000 (team interest generation + player decisions)
	var output := FreeAgency.run_free_agency(
		world_state,
		year,
		step_seed,
		positions_cfg,
		main_cfg,
		stats_cfg,
		league_cfg
	)

	return {
		"year": year,
		"signings": int(output.get("signings", []).size()),
		"unsigned": int(output.get("unsigned", []).size()),
		"franchise_tags": int(output.get("franchise_tags", []).size()),
		"total_spent": float(output.get("total_spent", 0.0)),
		"step_seeds": {"nfl_free_agency": step_seed}
	}

func _handle_nfl_season(
	world_state: Dictionary,
	year: int,
	_seed: int,
	phase: Dictionary,
	year_seed: int
) -> Dictionary:
	var phase_id := String(phase.get("phase_id", ""))
	var step_seed := _derive_seed(year_seed, phase_id, "nfl_season")
	_log_step_seed(year, phase_id, "nfl_season", step_seed)

	var league_cfg: Dictionary = _get_config().get_config("world/league")
	var positions_cfg: Dictionary = _get_config().get_config("positions")
	var main_cfg: Dictionary = _get_config().get_config("main")
	var stats_cfg: Dictionary = _get_config().get_config("stats")

	var season := NflSeason.new()
	return season.run(world_state, year, step_seed, league_cfg, positions_cfg, main_cfg, stats_cfg, _lifecycle_options())

func _handle_placeholder_phase(
	_world_state: Dictionary,
	_year: int,
	_seed: int,
	phase: Dictionary,
	_year_seed: int
) -> Dictionary:
	# TODO: Implement phase handler with explicit RNG usage and output schema.
	# Determinism: this placeholder does not consume RNG.
	return {
		"placeholder": true,
		"note": "Phase '%s' not yet implemented." % String(phase.get("phase_id", ""))
	}

func _handle_unknown_phase(
	_world_state: Dictionary,
	_year: int,
	_seed: int,
	phase: Dictionary,
	_year_seed: int
) -> Dictionary:
	return {
		"error": "No handler for phase '%s'." % String(phase.get("phase_id", ""))
	}

func _log_phase_start(year: int, phase_id: String, seed: int) -> void:
	var timestamp := _get_timestamp()
	print("%s %d %s: start (seed=%d)" % [timestamp, year, phase_id, seed])

func _log_phase_end(year: int, phase_id: String, seed: int) -> void:
	var timestamp := _get_timestamp()
	print("%s %d %s: end (seed=%d)" % [timestamp, year, phase_id, seed])

func _log_step_seed(year: int, phase_id: String, step_id: String, seed: int) -> void:
	var timestamp := _get_timestamp()
	print("%s %d %s.%s: step (seed=%d)" % [timestamp, year, phase_id, step_id, seed])

## Logs a formatted summary of phase execution with key metrics and timing
func _log_phase_summary(phase_id: String, year: int, output: Dictionary, elapsed_ms: float) -> void:
	var metrics: Array = []

	# Standard metrics that phases might return
	if output.has("picks_count"):
		metrics.append("picks=%d" % output["picks_count"])
	if output.has("undrafted_count"):
		metrics.append("undrafted=%d" % output["undrafted_count"])
	if output.has("signings"):
		var signings_count: int = output["signings"] if output["signings"] is int else len(output["signings"])
		metrics.append("signings=%d" % signings_count)
	if output.has("unsigned"):
		var unsigned_count: int = output["unsigned"] if output["unsigned"] is int else len(output["unsigned"])
		metrics.append("unsigned=%d" % unsigned_count)
	if output.has("retirements"):
		metrics.append("retirements=%d" % output["retirements"])
	if output.has("total_spent"):
		metrics.append("spent=$%.2fM" % output["total_spent"])
	if output.has("trades"):
		metrics.append("trades=%d" % output["trades"])
	if output.has("franchise_tags"):
		var tags_count: int = output["franchise_tags"] if output["franchise_tags"] is int else len(output["franchise_tags"])
		metrics.append("tags=%d" % tags_count)
	if output.has("offers"):
		metrics.append("offers=%d" % output["offers"])
	if output.has("commitments"):
		var commits_count: int = output["commitments"] if output["commitments"] is int else len(output["commitments"])
		metrics.append("commits=%d" % commits_count)

	var summary: String = " | ".join(metrics) if not metrics.is_empty() else "complete"
	var timestamp := _get_timestamp()
	print("%s %d %s: %s (%.1fms)" % [timestamp, year, phase_id.to_upper(), summary, elapsed_ms])

## Returns current timestamp in HH:MM:SS format
func _get_timestamp() -> String:
	var time := Time.get_time_dict_from_system()
	return "%02d:%02d:%02d" % [time["hour"], time["minute"], time["second"]]

func _derive_seed(year_seed: int, phase_id: String, step_id: String) -> int:
	var key := "%s:%s" % [phase_id, step_id]
	var hash := _fnv1a_64(key)
	return Rand.splitmix64(year_seed ^ hash)

func _fnv1a_64(text: String) -> int:
	var hash: int = -3750763034362895579
	var prime: int = 1099511628211
	for b in text.to_utf8_buffer():
		hash = int(hash ^ b) & -1
		hash = int(hash * prime) & -1
	return hash

func _school_index(schools: Array) -> Dictionary:
	var out := {}
	for school in schools:
		var s: Dictionary = school
		var sid := String(s.get("id", ""))
		if sid != "":
			out[sid] = s
	return out

func _apply_hs_player_fields(players: Array, year: int, cfg: Dictionary, seed: int) -> void:
	var eligibility_cfg: Dictionary = cfg.get("eligibility", {}) as Dictionary
	var hs_years := int(eligibility_cfg.get("hs_years", 4))
	var regions: Array = cfg.get("regions", []) as Array
	var region_weights := _weights_for(regions)
	var assign_cfg: Dictionary = cfg.get("assignment", {}) as Dictionary
	var bias_min := float(assign_cfg.get("proximity_bias_min", 0.4))
	var bias_max := float(assign_cfg.get("proximity_bias_max", 1.0))

	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed)

	for i in range(players.size()):
		var p: Dictionary = players[i]
		if p == null:
			continue
		if not p.has("player_id"):
			p["player_id"] = "hs-%d-%04d" % [year, i + 1]
		p["hs_year"] = 1
		p["hs_grad_year"] = year + hs_years - 1
		p["eligibility_status"] = "hs_underclass"
		p["hs_school_id"] = ""
		var region := _weighted_pick(regions, region_weights, rng)
		p["home_region"] = String(region.get("id", ""))
		p["proximity_bias"] = rng.randf_range(bias_min, bias_max)
		players[i] = p

## Generates HS background for each player (region, tier, stars, hype)
## This uses HighSchoolBackground for simplified one-time generation
## instead of complex multi-year school simulation.
##
## RNG consumption: 6-8 randf() calls per player
## Returns: Dictionary with generation stats for logging
func _apply_hs_backgrounds(players: Array, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed)

	# Track stats for logging
	var star_counts := {2: 0, 3: 0, 4: 0, 5: 0}
	var tier_counts := {"elite": 0, "good": 0, "avg": 0, "low": 0}
	var total_hype := 0.0
	var processed := 0

	for i in range(players.size()):
		var p: Dictionary = players[i]
		if p == null:
			continue

		# Generate HS background (region, tier, stars, dev modifier, hype)
		var background := HighSchoolBackground.generate_hs_background(p, rng)

		# Merge background fields into player
		for key in background.keys():
			p[key] = background[key]

		# Use hs_region as home_region if not already set (for recruiting proximity)
		if p.get("home_region", "") == "":
			p["home_region"] = String(background.get("hs_region", ""))

		players[i] = p
		processed += 1

		# Track stats
		var stars: int = background.get("recruiting_star_rating", 2)
		if star_counts.has(stars):
			star_counts[stars] += 1
		var tier: String = background.get("hs_program_tier", "avg")
		if tier_counts.has(tier):
			tier_counts[tier] += 1
		total_hype += float(background.get("initial_hype", 50.0))

	var avg_hype: float = total_hype / max(processed, 1)
	print("[HS Background] Generated %d backgrounds: stars=[5★:%d 4★:%d 3★:%d 2★:%d] tiers=[elite:%d good:%d avg:%d low:%d] avg_hype=%.1f" % [
		processed,
		star_counts[5], star_counts[4], star_counts[3], star_counts[2],
		tier_counts["elite"], tier_counts["good"], tier_counts["avg"], tier_counts["low"],
		avg_hype
	])

	return {
		"processed": processed,
		"star_distribution": star_counts,
		"tier_distribution": tier_counts,
		"avg_hype": avg_hype
	}

static func _weights_for(items: Array) -> Array:
	var weights: Array = []
	weights.resize(items.size())
	for i in range(items.size()):
		weights[i] = float((items[i] as Dictionary).get("weight", 0.0))
	return weights

static func _weighted_pick(items: Array, weights: Array, rng: RandomNumberGenerator) -> Dictionary:
	if items.is_empty():
		return {}
	var total := 0.0
	for w in weights:
		total += float(w)
	if total <= 0.0:
		return items[0] as Dictionary
	var roll := rng.randf() * total
	var running := 0.0
	for i in range(items.size()):
		running += float(weights[i])
		if roll <= running:
			return items[i] as Dictionary
	return items[items.size() - 1] as Dictionary

static func _build_recruit_profiles(graduates: Array, year: int) -> Array:
	var profiles: Array = []
	profiles.resize(graduates.size())
	for i in range(graduates.size()):
		var p: Dictionary = graduates[i]
		var profile := {
			"player_id": String(p.get("player_id", "")),
			"name": String(p.get("name", "")),
			"position": String(p.get("position", "")),
			"home_region": String(p.get("home_region", "")),
			"hs_school_id": String(p.get("hs_school_id", "")),
			"eligibility_status": String(p.get("eligibility_status", "")),
			"hs_grad_year": int(p.get("hs_grad_year", year)),
			"hs_stats": p.get("hs_stats", {}),
			"stats": p.get("stats", {}),
			"potential": p.get("potential", {}),
			"physicals": p.get("physicals", {}),
			"ratings": {
				"composite_score": float(p.get("composite_score", 0.0)),
				"star_score": float(p.get("star_score", 0.0)),
				"core_avg": float(p.get("core_avg", 0.0))
			},
			"source_year": year
		}
		profiles[i] = profile
	return profiles

## Filters HS graduates to only include college-eligible players.
## Uses rating threshold from config to determine eligibility.
## Returns filtered array of college-worthy players.
##
## RNG Usage: None (pure filtering based on existing ratings)
## Determinism: For identical input arrays and config, produces identical output
static func _filter_college_eligible(
	graduates: Array,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	hs_cfg: Dictionary
) -> Array:
	var recruiting_cfg: Dictionary = hs_cfg.get("recruiting", {}) as Dictionary
	var threshold := float(recruiting_cfg.get("college_eligibility_threshold", 0.0))
	var class_rules: Dictionary = main_cfg.get("class_rules", {}) as Dictionary

	var eligible := []

	for player in graduates:
		var p: Dictionary = player
		# Calculate overall rating using shared utility (same method as draft declaration)
		var rating := PlayerRatingCalculator.calculate_overall_rating(p, positions_cfg, class_rules)

		if rating >= threshold:
			eligible.append(p)

	return eligible


func _initialize_college_rosters(
	world_state: Dictionary,
	year: int,
	commitments: Array,
	recruits: Array
) -> void:
	var rosters: Dictionary = world_state.get("college_rosters", {}) as Dictionary
	var recruit_index := {}
	for recruit in recruits:
		var r: Dictionary = recruit
		var player_id := String(r.get("player_id", ""))
		if player_id != "":
			recruit_index[player_id] = r

	for commitment in commitments:
		var c: Dictionary = commitment
		var player_id := String(c.get("player_id", ""))
		var college_id := String(c.get("college_id", ""))
		if player_id == "" or college_id == "":
			continue

		var player: Dictionary = recruit_index.get(player_id, {}) as Dictionary
		if player.is_empty():
			continue

		var player_copy := player.duplicate(true)
		player_copy["college_id"] = college_id
		player_copy["college_year"] = 1
		player_copy["college_eligibility_status"] = "freshman"

		if not rosters.has(college_id):
			rosters[college_id] = {
				"players": [],
				"class_years": {1: [], 2: [], 3: [], 4: []}
			}

		var roster: Dictionary = rosters[college_id]
		(roster["players"] as Array).append(player_copy)
		var class_years: Dictionary = roster["class_years"]
		(class_years[1] as Array).append(player_id)

	world_state["college_rosters"] = rosters
