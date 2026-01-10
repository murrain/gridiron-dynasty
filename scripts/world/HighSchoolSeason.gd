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
	var context_rng := RandomNumberGenerator.new()
	context_rng.seed = Rand.splitmix64(seed ^ 0x4F8C21BD)

	var context_players := _apply_development_context(players, main_cfg, config, context_rng, year)

	var school_map := _school_index(schools)
	var prepared_players := _apply_development_contexts(context_players, school_map, config)
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
	var rehab_cfg: Dictionary = config.get("rehab_quality", {}) as Dictionary
	var default_rehab_mult := float(rehab_cfg.get("default_multiplier", 1.0))

	var updated: Array = []
	updated.resize(players.size())
	for i in range(players.size()):
		var p: Dictionary = players[i]
		if p == null:
			updated[i] = p
			continue
		var school_id := String(p.get("hs_school_id", ""))
		var school: Dictionary = school_map.get(school_id, {}) as Dictionary
		var context := _development_context_for(
			p,
			school,
			default_program_mult,
			position_specialists,
			default_rehab_mult
		)
		var next := p.duplicate(true)
		var existing: Dictionary = next.get("development_context", {}) as Dictionary
		for key in context.keys():
			existing[key] = context[key]
		next["development_context"] = existing
		updated[i] = next
	return updated

func _development_context_for(
	player: Dictionary,
	school: Dictionary,
	default_program_mult: float,
	position_specialists: Dictionary,
	default_rehab_mult: float
) -> Dictionary:
	var program_mult := float(school.get("program_quality_multiplier", default_program_mult))
	if program_mult <= 0.0:
		program_mult = default_program_mult

	var specialist_mult := 1.0
	var specialist_position := String(school.get("coach_specialist_position", ""))
	var position := String(player.get("position", ""))
	if specialist_position != "" and position == specialist_position:
		specialist_mult = float(position_specialists.get(specialist_position, 1.0))

	var rehab_mult := float(school.get("rehab_quality_multiplier", default_rehab_mult))
	if rehab_mult <= 0.0:
		rehab_mult = default_rehab_mult

	var applied_traits: Array = []
	if specialist_position != "" and position == specialist_position:
		applied_traits.append("position_specialist:%s" % specialist_position)

	return {
		"program_quality": program_mult,
		"coach_specialization": specialist_mult,
		"rehab_quality": rehab_mult,
		"program_quality_tier": String(school.get("program_quality_tier", "")),
		"coach_traits": school.get("coach_traits", []) as Array,
		"applied_traits": applied_traits
	}

func _apply_development_context(
	players: Array,
	main_cfg: Dictionary,
	config: Dictionary,
	rng: RandomNumberGenerator,
	year: int
) -> Array:
	var usage_cfg: Dictionary = config.get("usage_profile", {}) as Dictionary
	var competition_cfg: Dictionary = config.get("competition", {}) as Dictionary
	var dev_context_cfg: Dictionary = main_cfg.get("development_context", {}) as Dictionary
	var scheme_cfg: Dictionary = dev_context_cfg.get("scheme_fit", {}) as Dictionary
	var score_min := float(scheme_cfg.get("score_min", -0.15))
	var score_max := float(scheme_cfg.get("score_max", 0.15))

	var region_tiers: Dictionary = competition_cfg.get("region_tiers", {}) as Dictionary
	var tier_growths: Dictionary = competition_cfg.get("tier_growth_multipliers", {}) as Dictionary
	var default_tier := String(competition_cfg.get("default_tier", ""))
	var tier_usage: Dictionary = competition_cfg.get("tier_usage_multipliers", {}) as Dictionary
	var default_usage_mult := float(usage_cfg.get("default_multiplier", 1.0))

	var updated: Array = []
	updated.resize(players.size())
	for i in range(players.size()):
		var p: Dictionary = players[i]
		if p == null:
			updated[i] = p
			continue

		var usage_profile := _build_usage_profile(usage_cfg, rng)
		var usage_mult := default_usage_mult
		if bool(usage_profile.get("starter", false)):
			usage_mult = float(usage_cfg.get("starter_multiplier", default_usage_mult))
		var region_id := String(p.get("home_region", ""))
		var tier_id := String(region_tiers.get(region_id, default_tier))
		var growth_mult := float(tier_growths.get(tier_id, 1.0))
		var tier_mult := float(tier_usage.get(tier_id, 1.0))
		var scheme_score := rng.randf_range(score_min, score_max)

		var context := {
			"season": "hs",
			"year": year,
			"usage_profile": usage_profile,
			"usage": usage_mult,
			"competition_tier": growth_mult * tier_mult,
			"competition": {
				"tier_id": tier_id,
				"growth_multiplier": growth_mult,
				"region_id": region_id
			},
			"scheme_fit": {
				"score": scheme_score
			}
		}
		var next := p.duplicate(true)
		var existing: Dictionary = next.get("development_context", {}) as Dictionary
		for key in context.keys():
			existing[key] = context[key]
		next["development_context"] = existing
		updated[i] = next

	return updated

func _build_usage_profile(usage_cfg: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var games_min := int(usage_cfg.get("games_played_min", 8))
	var games_max := int(usage_cfg.get("games_played_max", 12))
	var snaps_min := int(usage_cfg.get("snaps_min", 150))
	var snaps_max := int(usage_cfg.get("snaps_max", 650))
	var starter_chance := float(usage_cfg.get("starter_chance", 0.35))

	var games_played := rng.randi_range(games_min, max(games_min, games_max))
	var snaps := rng.randi_range(snaps_min, max(snaps_min, snaps_max))
	var starter := rng.randf() < starter_chance

	return {
		"games_played": games_played,
		"snaps": snaps,
		"starter": starter
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
