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

	var progressed: Dictionary = PlayerLifecycle.advance_one_year(
		players,
		positions_cfg,
		main_cfg,
		stats_cfg,
		lifecycle_rng
	)
	var updated_players: Array = progressed.get("players", []) as Array

	var school_map := _school_index(schools)
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
