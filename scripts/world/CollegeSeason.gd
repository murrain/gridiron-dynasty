extends RefCounted
class_name CollegeSeason

const Rand = preload("res://autoloads/Rand.gd")
const PlayerLifecycle = preload("res://scripts/world/PlayerLifecycle.gd")

func run(
	world_state: Dictionary,
	year: int,
	seed: int,
	config: Dictionary,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	stats_cfg: Dictionary
) -> Dictionary:
	var rosters: Dictionary = world_state.get("college_rosters", {}) as Dictionary
	var colleges: Array = world_state.get("colleges", []) as Array

	if rosters.is_empty():
		return {
			"year": year,
			"rosters_updated": 0,
			"graduates": 0,
			"draft_eligible_count": 0,
			"early_declares": 0,
			"step_seeds": {}
		}

	var lifecycle_rng := RandomNumberGenerator.new()
	lifecycle_rng.seed = Rand.splitmix64(seed ^ 0xC011E6E1)
	var context_rng := RandomNumberGenerator.new()
	context_rng.seed = Rand.splitmix64(seed ^ 0xC011E6E2)
	var early_decl_rng := RandomNumberGenerator.new()
	early_decl_rng.seed = Rand.splitmix64(seed ^ 0xC011E6E3)

	var early_decl_cfg: Dictionary = config.get("early_declaration", {}) as Dictionary

	var college_index := _college_index(colleges)
	var draft_pool: Dictionary = world_state.get("draft_pool", {}) as Dictionary
	var draft_eligible: Array = draft_pool.get(year, []) as Array

	var total_graduates := 0
	var total_early_declares := 0
	var rosters_updated := 0

	for college_id in rosters.keys():
		var roster: Dictionary = rosters[college_id]
		var players: Array = roster.get("players", []) as Array
		if players.is_empty():
			continue

		var college: Dictionary = college_index.get(college_id, {}) as Dictionary
		var prepared_players := _apply_development_context(players, college, config, context_rng, year)

		var progressed: Dictionary = PlayerLifecycle.advance_one_year(
			prepared_players,
			positions_cfg,
			main_cfg,
			stats_cfg,
			lifecycle_rng
		)

		var updated_players: Array = progressed.get("players", []) as Array
		var active: Array = []
		var class_years := {1: [], 2: [], 3: [], 4: []}

		for i in range(updated_players.size()):
			var p: Dictionary = updated_players[i]
			if p == null:
				continue

			var old_year := int(p.get("college_year", 1))
			var new_year := old_year + 1
			p["college_year"] = new_year

			var new_status := _eligibility_status(new_year)
			p["college_eligibility_status"] = new_status

			var is_draft_eligible := false
			if new_year >= 4:
				# Seniors are automatically draft eligible
				is_draft_eligible = true
				total_graduates += 1
			elif new_year == 3:
				# Check for early declaration
				if _check_early_declaration(p, early_decl_cfg, early_decl_rng):
					is_draft_eligible = true
					total_early_declares += 1

			if is_draft_eligible:
				p["draft_eligible"] = true
				p["draft_year"] = year
				draft_eligible.append(p)
			else:
				active.append(p)
				if new_year >= 1 and new_year <= 4:
					(class_years[new_year] as Array).append(String(p.get("player_id", "")))

		roster["players"] = active
		roster["class_years"] = class_years
		rosters[college_id] = roster
		rosters_updated += 1

	world_state["college_rosters"] = rosters
	draft_pool[year] = draft_eligible
	world_state["draft_pool"] = draft_pool

	return {
		"year": year,
		"rosters_updated": rosters_updated,
		"graduates": total_graduates,
		"draft_eligible_count": draft_eligible.size(),
		"early_declares": total_early_declares,
		"step_seeds": {
			"lifecycle": lifecycle_rng.seed,
			"context": context_rng.seed,
			"early_declaration": early_decl_rng.seed
		}
	}

func _apply_development_context(
	players: Array,
	college: Dictionary,
	config: Dictionary,
	rng: RandomNumberGenerator,
	year: int
) -> Array:
	var usage_cfg: Dictionary = config.get("usage_profile", {}) as Dictionary
	var competition_cfg: Dictionary = config.get("competition", {}) as Dictionary

	var college_tier := String(college.get("tier", "mid"))
	var college_eliteness := float(college.get("eliteness", 50.0))
	var program_quality := college_eliteness / 100.0
	var tier_multipliers: Dictionary = competition_cfg.get("tier_growth_multipliers", {}) as Dictionary
	var competition_tier := float(tier_multipliers.get(college_tier, 1.0))

	var updated: Array = []
	updated.resize(players.size())

	for i in range(players.size()):
		var p: Dictionary = players[i]
		if p == null:
			updated[i] = p
			continue

		var usage := _roll_usage(usage_cfg, rng)
		var context := {
			"program_quality": program_quality,
			"competition_tier": competition_tier,
			"usage": usage,
			"season": "college",
			"year": year
		}

		var next := p.duplicate(true)
		next["development_context"] = context
		updated[i] = next

	return updated

func _roll_usage(usage_cfg: Dictionary, rng: RandomNumberGenerator) -> float:
	var starter_chance := float(usage_cfg.get("starter_chance", 0.45))
	var starter_mult := 1.2
	var bench_mult := 0.8

	if rng.randf() < starter_chance:
		return starter_mult
	else:
		return bench_mult

func _eligibility_status(college_year: int) -> String:
	match college_year:
		1:
			return "freshman"
		2:
			return "sophomore"
		3:
			return "junior"
		4:
			return "senior"
		_:
			return "senior"

func _check_early_declaration(
	player: Dictionary,
	early_decl_cfg: Dictionary,
	rng: RandomNumberGenerator
) -> bool:
	var min_year := int(early_decl_cfg.get("min_year", 3))
	var rating_threshold := float(early_decl_cfg.get("rating_threshold", 85.0))
	var base_chance := float(early_decl_cfg.get("base_chance", 0.15))
	var rating_bonus_per_point := float(early_decl_cfg.get("rating_bonus_per_point", 0.01))

	var college_year := int(player.get("college_year", 1))
	if college_year < min_year:
		return false

	var rating := _player_rating(player)
	if rating < rating_threshold:
		return false

	var chance := base_chance + (rating - rating_threshold) * rating_bonus_per_point
	chance = clamp(chance, 0.0, 0.95)

	return rng.randf() < chance

func _player_rating(player: Dictionary) -> float:
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

func _college_index(colleges: Array) -> Dictionary:
	var out := {}
	for college in colleges:
		var c: Dictionary = college
		var cid := String(c.get("id", ""))
		if cid != "":
			out[cid] = c
	return out
