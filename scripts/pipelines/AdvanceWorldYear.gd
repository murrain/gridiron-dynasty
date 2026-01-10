extends Node
class_name AdvanceWorldYear

func run(world_state: Dictionary, year: int, year_seed: int) -> Dictionary:
	var calendar := WorldCalendar.new()
	var phases := calendar.phases_for_year(year)
	var results: Array = []
	var state := world_state if world_state != null else {}

	var rng := RandomNumberGenerator.new()
	var resolved_year_seed := year_seed
	if year_seed != 0:
		rng.seed = year_seed
	else:
		rng.randomize()
		resolved_year_seed = int(rng.randi())

	var handlers := _phase_handlers()
	for phase in phases:
		var phase_id := String(phase.get("phase_id", ""))
		var phase_seed := _derive_seed(resolved_year_seed, phase_id, "phase")
		_log_phase_start(year, phase_id, phase_seed)
		var handler: Callable = handlers.get(phase_id, _handle_unknown_phase)
		var output: Dictionary = handler.call(state, year, phase_seed, phase, resolved_year_seed)
		_log_phase_end(year, phase_id, phase_seed)
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

	return {
		"year": year,
		"year_seed": resolved_year_seed,
		"year_seed_input": year_seed,
		"phases": results,
		"world_state": state
	}

func _phase_handlers() -> Dictionary:
	return {
		"hs_generation": Callable(self, "_handle_hs_generation"),
		"hs_assignment": Callable(self, "_handle_hs_assignment"),
		"hs_season": Callable(self, "_handle_hs_season"),
		"college_generation": Callable(self, "_handle_college_generation"),
		"college_recruiting": Callable(self, "_handle_college_recruiting"),
		"college_season": Callable(self, "_handle_placeholder_phase"),
		"draft_prep": Callable(self, "_handle_placeholder_phase"),
		"nfl_draft": Callable(self, "_handle_placeholder_phase")
	}

func _handle_hs_generation(
	world_state: Dictionary,
	year: int,
	_seed: int,
	phase: Dictionary,
	year_seed: int
) -> Dictionary:
	var phase_id := String(phase.get("phase_id", ""))
	var hs_cfg := Config.get_config("world/high_schools")
	var step_seeds := {
		"hs_school_gen": _derive_seed(year_seed, phase_id, "hs_school_gen"),
		"hs_player_gen": _derive_seed(year_seed, phase_id, "hs_player_gen"),
		"hs_player_meta": _derive_seed(year_seed, phase_id, "hs_player_meta")
	}
	for step_id in step_seeds.keys():
		_log_step_seed(year, phase_id, step_id, int(step_seeds[step_id]))

	var schools: Array = world_state.get("hs_schools", []) as Array
	if schools.is_empty():
		var school_gen := HighSchoolGenerator.new()
		var generated := school_gen.generate(step_seeds["hs_school_gen"])
		schools = generated.get("schools", []) as Array
		world_state["hs_schools"] = schools

	world_state["hs_school_index"] = _school_index(schools)

	var generator := DraftClassGenerator.new()
	var players := generator.generate_for_year(year, step_seeds["hs_player_gen"])
	_apply_hs_player_fields(players, year, hs_cfg, step_seeds["hs_player_meta"])

	var hs_players: Array = world_state.get("hs_players", []) as Array
	hs_players.append_array(players)
	world_state["hs_players"] = hs_players

	return {
		"class_year": year,
		"count": players.size(),
		"schools": schools.size(),
		"step_seeds": step_seeds
	}

func _handle_hs_assignment(
	world_state: Dictionary,
	year: int,
	_seed: int,
	phase: Dictionary,
	year_seed: int
) -> Dictionary:
	var phase_id := String(phase.get("phase_id", ""))
	var hs_cfg := Config.get_config("world/high_schools")
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

	var hs_cfg := Config.get_config("world/high_schools")
	var main_cfg := Config.get_config("main")
	var positions_cfg := Config.get_config("positions")
	var stats_cfg := Config.get_config("stats")

	var hs_players: Array = world_state.get("hs_players", []) as Array
	var hs_schools: Array = world_state.get("hs_schools", []) as Array
	var season := HighSchoolSeason.new()
	var output := season.run(hs_players, hs_schools, positions_cfg, main_cfg, stats_cfg, hs_cfg, step_seed, year)

	var active: Array = output.get("players", []) as Array
	var graduates: Array = output.get("graduates", []) as Array
	world_state["hs_players"] = active

	var recruit_pool: Dictionary = world_state.get("hs_recruit_pool", {}) as Dictionary
	var profiles := _build_recruit_profiles(graduates, year)
	recruit_pool[year] = profiles
	world_state["hs_recruit_pool"] = recruit_pool

	return {
		"year": year,
		"count": active.size(),
		"graduates": graduates.size(),
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

	var main_cfg := Config.get_config("main")
	var positions_cfg := Config.get_config("positions")
	var stats_cfg := Config.get_config("stats")
	var scouts_cfg := Config.get_config("scouts")
	var colleges_cfg := Config.get_config("world/colleges")

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

	return {
		"year": year,
		"offers": int(output.get("offers", 0)),
		"commitments": commitments.size(),
		"uncommitted": (output.get("uncommitted", []) as Array).size(),
		"step_seeds": {"college_recruiting": step_seed}
	}

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
	print("WorldYear: start phase %s year=%d seed=%d" % [phase_id, year, seed])

func _log_phase_end(year: int, phase_id: String, seed: int) -> void:
	print("WorldYear: end phase %s year=%d seed=%d" % [phase_id, year, seed])

func _log_step_seed(year: int, phase_id: String, step_id: String, seed: int) -> void:
	print("WorldYear: step %s.%s year=%d seed=%d" % [phase_id, step_id, year, seed])

func _derive_seed(year_seed: int, phase_id: String, step_id: String) -> int:
	var key := "%s:%s" % [phase_id, step_id]
	var hash := _fnv1a_64(key)
	return Rand.splitmix64(year_seed ^ hash)

func _fnv1a_64(text: String) -> int:
	var hash := 0xcbf29ce484222325
	var prime := 0x100000001b3
	for b in text.to_utf8_buffer():
		hash = int(hash ^ b) & 0xFFFFFFFFFFFFFFFF
		hash = int(hash * prime) & 0xFFFFFFFFFFFFFFFF
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

func _weights_for(items: Array) -> Array:
	var weights: Array = []
	weights.resize(items.size())
	for i in range(items.size()):
		weights[i] = float((items[i] as Dictionary).get("weight", 0.0))
	return weights

func _weighted_pick(items: Array, weights: Array, rng: RandomNumberGenerator) -> Dictionary:
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

func _build_recruit_profiles(graduates: Array, year: int) -> Array:
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
