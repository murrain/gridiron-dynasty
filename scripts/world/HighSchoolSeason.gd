extends RefCounted
class_name HighSchoolSeason

const Rand = preload("res://autoloads/Rand.gd")
const PlayerLifecycle = preload("res://scripts/world/PlayerLifecycle.gd")

func run(
	players: Array,
	schools: Array,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	stats_cfg: Dictionary,
	config: Dictionary,
	seed: int,
	year: int
) -> Dictionary:
	var eligibility_cfg: Dictionary = config.get("eligibility", {}) as Dictionary
	var hs_years := int(eligibility_cfg.get("hs_years", 4))
	var underclass_years := int(eligibility_cfg.get("underclass_years", 2))

	var lifecycle_rng := RandomNumberGenerator.new()
	lifecycle_rng.seed = Rand.splitmix64(seed ^ 0xA54C3D5E)
	var perf_rng := RandomNumberGenerator.new()
	perf_rng.seed = Rand.splitmix64(seed ^ 0x1E0C7A11)

	var school_map := _school_index(schools)
	var prepared_players := _apply_development_contexts(players, school_map, config)
	var progressed: Dictionary = PlayerLifecycle.advance_one_year(
		prepared_players,
		positions_cfg,
		main_cfg,
		stats_cfg,
		lifecycle_rng
	)
	var updated_players: Array = progressed.get("players", []) as Array

	var transitions: Array = []
	var graduates: Array = []
	var active: Array = []

	for i in range(updated_players.size()):
		var p: Dictionary = updated_players[i]
		if p == null:
			continue

		var old_year := int(p.get("hs_year", 1))
		var old_status := String(p.get("eligibility_status", "hs_underclass"))
		var new_year := old_year + 1
		p["hs_year"] = new_year

		var new_status := "hs_upperclass"
		var graduated := false
		if new_year >= hs_years:
			new_status = "hs_grad"
			graduated = true
		elif new_year <= underclass_years:
			new_status = "hs_underclass"
		p["eligibility_status"] = new_status

		var performance := _performance_bundle(p, school_map, config, perf_rng, year)
		p["hs_stats"] = performance

		transitions.append({
			"player_id": String(p.get("player_id", "")),
			"name": String(p.get("name", "")),
			"old_hs_year": old_year,
			"new_hs_year": new_year,
			"old_status": old_status,
			"new_status": new_status,
			"graduated": graduated
		})

		if graduated:
			graduates.append(p)
		else:
			active.append(p)

	return {
		"players": active,
		"graduates": graduates,
		"transitions": transitions
	}

func _apply_development_contexts(players: Array, school_map: Dictionary, config: Dictionary) -> Array:
	var program_cfg: Dictionary = config.get("program_quality", {}) as Dictionary
	var default_program_mult := float(program_cfg.get("default_dev_multiplier", 1.0))
	var position_specialists: Dictionary = config.get("position_specialists", {}) as Dictionary

	var updated: Array = []
	updated.resize(players.size())
	for i in range(players.size()):
		var p: Dictionary = players[i]
		if p == null:
			updated[i] = p
			continue
		var school_id := String(p.get("hs_school_id", ""))
		var school: Dictionary = school_map.get(school_id, {}) as Dictionary
		var context := _development_context_for(p, school, default_program_mult, position_specialists)
		var next := p.duplicate(true)
		next["development_context"] = context
		updated[i] = next
	return updated

func _development_context_for(
	player: Dictionary,
	school: Dictionary,
	default_program_mult: float,
	position_specialists: Dictionary
) -> Dictionary:
	var program_mult := float(school.get("program_quality_multiplier", default_program_mult))
	if program_mult <= 0.0:
		program_mult = default_program_mult

	var specialist_mult := 1.0
	var specialist_position := String(school.get("coach_specialist_position", ""))
	var position := String(player.get("position", ""))
	if specialist_position != "" and position == specialist_position:
		specialist_mult = float(position_specialists.get(specialist_position, 1.0))

	var total_mult := program_mult * specialist_mult
	var applied_traits: Array = []
	if specialist_position != "" and position == specialist_position:
		applied_traits.append("position_specialist:%s" % specialist_position)

	return {
		"multipliers": {
			"growth": total_mult,
			"prime": total_mult,
			"decline": total_mult
		},
		"program_quality_tier": String(school.get("program_quality_tier", "")),
		"program_quality_multiplier": program_mult,
		"coach_traits": school.get("coach_traits", []) as Array,
		"applied_traits": applied_traits
	}

func _performance_bundle(
	player: Dictionary,
	school_map: Dictionary,
	config: Dictionary,
	rng: RandomNumberGenerator,
	year: int
) -> Dictionary:
	var perf_cfg: Dictionary = config.get("performance", {}) as Dictionary
	var base_min := float(perf_cfg.get("base_min", 40.0))
	var base_max := float(perf_cfg.get("base_max", 70.0))
	var rating_weight := float(perf_cfg.get("rating_weight", 0.6))
	var school_weight := float(perf_cfg.get("school_eliteness_weight", 0.2))
	var noise_min := float(perf_cfg.get("noise_min", -5.0))
	var noise_max := float(perf_cfg.get("noise_max", 5.0))

	var base := rng.randf_range(base_min, base_max)
	var rating := _player_strength(player)
	var school_eliteness := 0.0
	var school_id := String(player.get("hs_school_id", ""))
	if school_map.has(school_id):
		school_eliteness = float((school_map[school_id] as Dictionary).get("eliteness", 0.0))

	var score := base + rating * rating_weight + school_eliteness * school_weight
	if noise_min != 0.0 or noise_max != 0.0:
		score += rng.randf_range(noise_min, noise_max)

	return {
		"year": year,
		"performance_score": clamp(score, 0.0, 100.0),
		"school_id": school_id,
		"rating_basis": rating
	}

func _school_index(schools: Array) -> Dictionary:
	var out := {}
	for school in schools:
		var s: Dictionary = school
		var sid := String(s.get("id", ""))
		if sid != "":
			out[sid] = s
	return out

func _player_strength(player: Dictionary) -> float:
	if player.has("composite_score"):
		return float(player.get("composite_score", 0.0))
	if player.has("core_avg"):
		return float(player.get("core_avg", 0.0))
	var stats: Dictionary = player.get("stats", {}) as Dictionary
	var total := 0.0
	var count := 0
	for val in stats.values():
		if typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
			total += float(val)
			count += 1
	return (total / float(count)) if count > 0 else 0.0
