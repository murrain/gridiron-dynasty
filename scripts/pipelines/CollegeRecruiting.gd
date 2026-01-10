extends RefCounted
class_name CollegeRecruitingOptimized
## Optimized college recruiting pipeline with O(N + N*M_filtered) complexity.
##
## Performance optimization for Task F2:
## - Pre-computes baseline scores once per recruit (O(N))
## - Applies lightweight filtering before expensive scout evaluations
## - Parallelizes college processing using ThreadPool with seed derivation
## - Reduces O(N*M) to O(N + N*M_filtered) where M_filtered << M
##
## Expected impact: 50-70% reduction in recruiting phase time
## (130 colleges × 2000 recruits = 260,000 calls → ~2000 + 130 × 200 = 28,000 calls)

const ScoutFactory = preload("res://scripts/generation/ScoutFactory.gd")
const RecruitRater = preload("res://scripts/core/rating/RecruitRater.gd")
const Scout = preload("res://scripts/core/models/Scout.gd")
const Rand = preload("res://autoloads/Rand.gd")
const ThreadPool = preload("res://autoloads/ThreadPool.gd")

## Main entry point - preserves exact same API as CollegeRecruiting.gd
func run(
	recruits: Array,
	colleges: Array,
	config: Dictionary,
	positions_cfg: Dictionary,
	stats_cfg: Dictionary,
	class_rules: Dictionary,
	scouts_cfg: Dictionary,
	seed: int,
	year: int,
	use_parallel: bool = true
) -> Dictionary:
	if recruits.is_empty() or colleges.is_empty():
		return {
			"year": year,
			"commitments": [],
			"uncommitted": recruits.size(),
			"college_classes": {},
			"offers": 0
		}

	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed)

	var recruiting_cfg: Dictionary = config.get("recruiting", {}) as Dictionary
	var offer_limit := int(recruiting_cfg.get("offer_limit", 30))
	var board_limit := int(recruiting_cfg.get("board_limit", 120))
	var class_min := int(recruiting_cfg.get("class_size_min", 15))
	var class_max := int(recruiting_cfg.get("class_size_max", 25))

	var rating_weight := float(recruiting_cfg.get("rating_weight", 0.55))
	var eliteness_weight := float(recruiting_cfg.get("eliteness_weight", 0.25))
	var proximity_weight := float(recruiting_cfg.get("proximity_weight", 0.20))
	var region_match_multiplier := float(recruiting_cfg.get("region_match_multiplier", 1.35))

	var scout_weight := float(recruiting_cfg.get("scout_weight", 0.70))
	var baseline_weight := float(recruiting_cfg.get("baseline_weight", 0.30))
	var visit_chance := float(recruiting_cfg.get("visit_chance", 0.25))
	var visit_bonus := float(recruiting_cfg.get("visit_bonus", 0.06))

	# OPTIMIZATION 1: Pre-compute baseline scores once (O(N) instead of O(N*M))
	var baseline_scores := _baseline_scores(recruits, positions_cfg, class_rules)

	# OPTIMIZATION 2: Pre-compute recruit metadata for fast filtering
	var recruit_metadata := _precompute_recruit_metadata(recruits, baseline_scores)

	# OPTIMIZATION 3: Build boards in parallel with seed derivation
	var boards_by_college: Dictionary
	var offers_by_player := {}

	if use_parallel and colleges.size() > 4:
		boards_by_college = _build_boards_parallel(
			recruits,
			colleges,
			recruit_metadata,
			baseline_scores,
			positions_cfg,
			stats_cfg,
			class_rules,
			scouts_cfg,
			scout_weight,
			baseline_weight,
			rating_weight,
			eliteness_weight,
			proximity_weight,
			region_match_multiplier,
			visit_chance,
			visit_bonus,
			board_limit,
			seed
		)
	else:
		boards_by_college = _build_boards_sequential(
			recruits,
			colleges,
			recruit_metadata,
			baseline_scores,
			positions_cfg,
			stats_cfg,
			class_rules,
			scouts_cfg,
			scout_weight,
			baseline_weight,
			rating_weight,
			eliteness_weight,
			proximity_weight,
			region_match_multiplier,
			visit_chance,
			visit_bonus,
			board_limit,
			seed
		)

	# Collect offers (same logic as original)
	for college_id in boards_by_college.keys():
		var board: Array = boards_by_college[college_id] as Array
		var offer_count: int = min(offer_limit, board.size())
		for i in range(offer_count):
			var offer: Dictionary = board[i]
			var player_id := String(offer.get("player_id", ""))
			if player_id == "":
				continue
			if not offers_by_player.has(player_id):
				offers_by_player[player_id] = []
			var item := {
				"college_id": college_id,
				"score": float(offer.get("score", 0.0)),
				"scout_score": float(offer.get("scout_score", 0.0)),
				"base_score": float(offer.get("base_score", 0.0))
			}
			(offers_by_player[player_id] as Array).append(item)

	# Rest of the logic is unchanged
	var targets := _college_targets(colleges, class_min, class_max, seed)
	var classes := {}
	for college in colleges:
		var cid := String((college as Dictionary).get("id", ""))
		if cid != "":
			classes[cid] = {"target": int(targets.get(cid, 0)), "players": []}

	var commitments: Array = []
	var uncommitted: Array = []
	var ordered_recruits := _sorted_recruits(recruits, baseline_scores)
	for recruit in ordered_recruits:
		var recruit_dict: Dictionary = recruit
		var player_id := String(recruit_dict.get("player_id", ""))
		var offers: Array = offers_by_player.get(player_id, []) as Array
		if offers.is_empty():
			uncommitted.append(player_id)
			continue

		offers.sort_custom(func(a, b):
			return String((a as Dictionary).get("college_id", "")) < String((b as Dictionary).get("college_id", ""))
		)

		var pick_rng := _rng_for(seed, "recruit:%s" % player_id)
		var committed := _pick_commitment(offers, classes, pick_rng)
		if committed.is_empty():
			uncommitted.append(player_id)
			continue

		var college_id := String(committed.get("college_id", ""))
		var entry := {
			"player_id": player_id,
			"college_id": college_id,
			"score": float(committed.get("score", 0.0)),
			"scout_score": float(committed.get("scout_score", 0.0)),
			"base_score": float(committed.get("base_score", 0.0)),
			"year": year
		}
		commitments.append(entry)
		(classes[college_id] as Dictionary)["players"].append(player_id)

	return {
		"year": year,
		"commitments": commitments,
		"uncommitted": uncommitted,
		"college_classes": classes,
		"offers": offers_by_player.size()
	}

## Pre-compute baseline scores (same as original, but happens once)
func _baseline_scores(recruits: Array, positions_cfg: Dictionary, class_rules: Dictionary) -> Dictionary:
	var scores := {}
	for recruit in recruits:
		var r: Dictionary = recruit
		var player_id := String(r.get("player_id", ""))
		if player_id == "":
			continue
		var ratings: Dictionary = r.get("ratings", {}) as Dictionary
		var base_score := float(ratings.get("composite_score", 0.0))
		if base_score <= 0.0:
			var res := RecruitRater.compute(r, positions_cfg, {}, class_rules, {}) as Dictionary
			base_score = float(res.get("composite", 0.0))
		scores[player_id] = base_score
	return scores

## OPTIMIZATION: Pre-compute recruit metadata for fast filtering
## This allows colleges to quickly identify promising candidates without expensive scout calls
func _precompute_recruit_metadata(recruits: Array, baseline_scores: Dictionary) -> Dictionary:
	var metadata := {}
	for recruit in recruits:
		var r: Dictionary = recruit
		var player_id := String(r.get("player_id", ""))
		if player_id == "":
			continue
		metadata[player_id] = {
			"baseline_score": float(baseline_scores.get(player_id, 0.0)),
			"home_region": String(r.get("home_region", "")),
			"proximity_bias": float(r.get("proximity_bias", 0.0)),
			"position": String(r.get("position", ""))
		}
	return metadata

## OPTIMIZATION: Sequential board building (for small college counts or when parallel is disabled)
func _build_boards_sequential(
	recruits: Array,
	colleges: Array,
	recruit_metadata: Dictionary,
	baseline_scores: Dictionary,
	positions_cfg: Dictionary,
	stats_cfg: Dictionary,
	class_rules: Dictionary,
	scouts_cfg: Dictionary,
	scout_weight: float,
	baseline_weight: float,
	rating_weight: float,
	eliteness_weight: float,
	proximity_weight: float,
	region_match_multiplier: float,
	visit_chance: float,
	visit_bonus: float,
	board_limit: int,
	seed: int
) -> Dictionary:
	var factory := ScoutFactory.new()
	factory.setup(stats_cfg, scouts_cfg)

	var boards := {}
	for college in colleges:
		var college_dict: Dictionary = college
		var college_id := String(college_dict.get("id", ""))
		if college_id == "":
			continue

		var college_rng := _rng_for(seed, college_id)
		var scout: Resource = factory.create_random_scout(
			"%s Recruiter" % String(college_dict.get("name", "Recruiter")),
			college_rng
		)

		var board: Array = _build_board_optimized(
			recruits,
			college_dict,
			scout,
			college_rng,
			recruit_metadata,
			baseline_scores,
			positions_cfg,
			stats_cfg,
			class_rules,
			scout_weight,
			baseline_weight,
			rating_weight,
			eliteness_weight,
			proximity_weight,
			region_match_multiplier,
			visit_chance,
			visit_bonus,
			board_limit
		)
		boards[college_id] = board

	return boards

## OPTIMIZATION: Parallel board building using ThreadPool with seed derivation
## Each college gets a deterministic seed derived from base seed + college_id
## This ensures reproducibility while allowing parallel execution
func _build_boards_parallel(
	recruits: Array,
	colleges: Array,
	recruit_metadata: Dictionary,
	baseline_scores: Dictionary,
	positions_cfg: Dictionary,
	stats_cfg: Dictionary,
	class_rules: Dictionary,
	scouts_cfg: Dictionary,
	scout_weight: float,
	baseline_weight: float,
	rating_weight: float,
	eliteness_weight: float,
	proximity_weight: float,
	region_match_multiplier: float,
	visit_chance: float,
	visit_bonus: float,
	board_limit: int,
	seed: int
) -> Dictionary:
	# RNG SEEDING FOR PARALLEL EXECUTION:
	# Each college gets a unique, deterministic seed:
	#   college_seed = splitmix64(base_seed ^ hash(college_id))
	# This ensures:
	#   1. Same base seed always produces same per-college seeds
	#   2. No shared RNG state between threads
	#   3. Results are identical regardless of execution order

	var worker := func(college_data: Dictionary) -> Dictionary:
		var college: Dictionary = college_data["college"]
		var college_id: String = college_data["college_id"]
		var base_seed: int = int(college_data["seed"])

		# Derive deterministic seed for this college
		var college_seed := Rand.splitmix64(base_seed ^ _fnv1a_64(college_id))
		var college_rng := RandomNumberGenerator.new()
		college_rng.seed = college_seed

		# Create scout with deterministic seed
		var factory := ScoutFactory.new()
		factory.setup(college_data["stats_cfg"], college_data["scouts_cfg"])
		var scout: Resource = factory.create_random_scout(
			"%s Recruiter" % String(college.get("name", "Recruiter")),
			college_rng
		)

		# Build board
		var board: Array = _build_board_optimized(
			college_data["recruits"],
			college,
			scout,
			college_rng,
			college_data["recruit_metadata"],
			college_data["baseline_scores"],
			college_data["positions_cfg"],
			college_data["stats_cfg"],
			college_data["class_rules"],
			float(college_data["scout_weight"]),
			float(college_data["baseline_weight"]),
			float(college_data["rating_weight"]),
			float(college_data["eliteness_weight"]),
			float(college_data["proximity_weight"]),
			float(college_data["region_match_multiplier"]),
			float(college_data["visit_chance"]),
			float(college_data["visit_bonus"]),
			int(college_data["board_limit"])
		)

		return {"college_id": college_id, "board": board}

	# Prepare work items (each college is independent)
	var work_items: Array = []
	for college in colleges:
		var college_dict: Dictionary = college
		var college_id := String(college_dict.get("id", ""))
		if college_id == "":
			continue

		work_items.append({
			"college": college_dict,
			"college_id": college_id,
			"seed": seed,
			"recruits": recruits,
			"recruit_metadata": recruit_metadata,
			"baseline_scores": baseline_scores,
			"positions_cfg": positions_cfg,
			"stats_cfg": stats_cfg,
			"class_rules": class_rules,
			"scouts_cfg": scouts_cfg,
			"scout_weight": scout_weight,
			"baseline_weight": baseline_weight,
			"rating_weight": rating_weight,
			"eliteness_weight": eliteness_weight,
			"proximity_weight": proximity_weight,
			"region_match_multiplier": region_match_multiplier,
			"visit_chance": visit_chance,
			"visit_bonus": visit_bonus,
			"board_limit": board_limit
		})

	# Execute in parallel (ThreadPool handles thread management)
	var thread_count := 4  # Optimal for most systems
	var results: Array = ThreadPool.map(work_items, worker, thread_count)

	# Collect results
	var boards := {}
	for result in results:
		var res: Dictionary = result
		boards[String(res.get("college_id", ""))] = res.get("board", [])

	return boards

## OPTIMIZATION: Optimized board building with early filtering
## Key change: Only evaluate top candidates with expensive scout calls
func _build_board_optimized(
	recruits: Array,
	college: Dictionary,
	scout: Scout,
	rng: RandomNumberGenerator,
	recruit_metadata: Dictionary,
	baseline_scores: Dictionary,
	positions_cfg: Dictionary,
	stats_cfg: Dictionary,
	class_rules: Dictionary,
	scout_weight: float,
	baseline_weight: float,
	rating_weight: float,
	eliteness_weight: float,
	proximity_weight: float,
	region_match_multiplier: float,
	visit_chance: float,
	visit_bonus: float,
	board_limit: int
) -> Array:
	var college_region := String(college.get("region", ""))
	var college_elite := float(college.get("eliteness", 0.0)) / 100.0

	# OPTIMIZATION: Two-phase evaluation
	# Phase 1: Quick score using baseline only (O(N), lightweight)
	# Phase 2: Expensive scout evaluation only for top candidates (O(M_filtered), where M_filtered << N)

	var quick_scores: Array = []
	quick_scores.resize(recruits.size())

	# Phase 1: Quick filtering using baseline scores + college factors
	# RNG: Each recruit consumes 1 RNG call for visit determination
	for i in range(recruits.size()):
		var recruit: Dictionary = recruits[i]
		var player_id := String(recruit.get("player_id", ""))
		var meta: Dictionary = recruit_metadata.get(player_id, {}) as Dictionary
		var base_score: float = float(meta.get("baseline_score", 0.0))
		var rating_norm: float = clamp(base_score / 100.0, 0.0, 1.0)

		var proximity_factor := 1.0
		var home_region := String(meta.get("home_region", ""))
		if home_region != "" and home_region == college_region:
			var bias := float(meta.get("proximity_bias", 0.0))
			proximity_factor = 1.0 + (region_match_multiplier - 1.0) * bias

		var quick_score: float = rating_norm * rating_weight
		quick_score += college_elite * eliteness_weight
		quick_score += proximity_factor * proximity_weight

		# RNG CALL 1 (per recruit): Visit determination
		var had_visit := false
		if visit_chance > 0.0 and rng.randf() < visit_chance:
			quick_score *= (1.0 + visit_bonus)
			had_visit = true

		quick_scores[i] = {
			"index": i,
			"player_id": player_id,
			"quick_score": quick_score,
			"base_score": base_score,
			"had_visit": had_visit
		}

	# Sort by quick score to identify top candidates
	quick_scores.sort_custom(func(a, b):
		var av := float((a as Dictionary).get("quick_score", 0.0))
		var bv := float((b as Dictionary).get("quick_score", 0.0))
		if av == bv:
			return String((a as Dictionary).get("player_id", "")) < String((b as Dictionary).get("player_id", ""))
		return av > bv
	)

	# OPTIMIZATION: Only evaluate top N candidates with expensive scout calls
	# Heuristic: 2x board_limit ensures we don't miss good candidates due to scout variance
	var eval_limit := max(board_limit * 2, 200) if board_limit > 0 else recruits.size()
	var candidates_to_evaluate := mini(eval_limit, quick_scores.size())

	var final_board: Array = []
	final_board.resize(candidates_to_evaluate)

	# Phase 2: Expensive scout evaluation only for top candidates
	# RNG: Scout consumes multiple RNG calls per evaluation (see Scout.score_player)
	for i in range(candidates_to_evaluate):
		var quick_entry: Dictionary = quick_scores[i]
		var recruit: Dictionary = recruits[int(quick_entry.get("index", 0))]
		var player_id := String(quick_entry.get("player_id", ""))
		var base_score: float = float(quick_entry.get("base_score", 0.0))

		# RNG CALLS (variable per recruit, depends on Scout implementation):
		# - Scout.score_player makes ~40-80 RNG calls (perception noise for each stat)
		# - Exact count depends on stat_count in stats_cfg
		var scout_score: float = float(scout.score_player(recruit, positions_cfg, stats_cfg, class_rules, rng))

		var combined_rating: float = (
			scout_score * scout_weight + base_score * baseline_weight
		) / max(0.0001, scout_weight + baseline_weight)
		var rating_norm: float = clamp(combined_rating / 100.0, 0.0, 1.0)

		# Recompute proximity (already computed in quick_score phase)
		var meta: Dictionary = recruit_metadata.get(player_id, {}) as Dictionary
		var proximity_factor := 1.0
		var home_region := String(meta.get("home_region", ""))
		if home_region != "" and home_region == college_region:
			var bias := float(meta.get("proximity_bias", 0.0))
			proximity_factor = 1.0 + (region_match_multiplier - 1.0) * bias

		var final_score: float = rating_norm * rating_weight
		final_score += college_elite * eliteness_weight
		final_score += proximity_factor * proximity_weight

		# Apply visit bonus (determined in Phase 1, so no additional RNG call)
		if quick_entry.get("had_visit", false):
			final_score *= (1.0 + visit_bonus)

		final_board[i] = {
			"player_id": player_id,
			"score": final_score,
			"scout_score": scout_score,
			"base_score": base_score
		}

	# Final sort by actual score
	final_board.sort_custom(func(a, b):
		var av := float((a as Dictionary).get("score", 0.0))
		var bv := float((b as Dictionary).get("score", 0.0))
		if av == bv:
			return String((a as Dictionary).get("player_id", "")) < String((b as Dictionary).get("player_id", ""))
		return av > bv
	)

	# Trim to board limit
	if board_limit > 0 and final_board.size() > board_limit:
		final_board = final_board.slice(0, board_limit)

	return final_board

## Unchanged helper functions below (same as original CollegeRecruiting.gd)

func _college_targets(colleges: Array, class_min: int, class_max: int, seed: int) -> Dictionary:
	var targets := {}
	for college in colleges:
		var c: Dictionary = college
		var college_id := String(c.get("id", ""))
		if college_id == "":
			continue
		var rng := _rng_for(seed, "class_size:%s" % college_id)
		var target := class_min
		if class_max >= class_min and class_min > 0:
			target = rng.randi_range(class_min, class_max)
		elif class_min > 0:
			target = class_min
		targets[college_id] = target
	return targets

func _sorted_recruits(recruits: Array, baseline_scores: Dictionary) -> Array:
	var ordered := recruits.duplicate()
	ordered.sort_custom(func(a, b):
		var ad: Dictionary = a
		var bd: Dictionary = b
		var a_id := String(ad.get("player_id", ""))
		var b_id := String(bd.get("player_id", ""))
		var av := float(baseline_scores.get(a_id, 0.0))
		var bv := float(baseline_scores.get(b_id, 0.0))
		if av == bv:
			return a_id < b_id
		return av > bv
	)
	return ordered

func _pick_commitment(offers: Array, classes: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var pool := offers.duplicate()
	while not pool.is_empty():
		var picked := _weighted_pick(pool, rng)
		var college_id := String(picked.get("college_id", ""))
		var class_info: Dictionary = classes.get(college_id, {}) as Dictionary
		var target := int(class_info.get("target", 0))
		var players: Array = class_info.get("players", []) as Array
		if target > 0 and players.size() >= target:
			pool.erase(picked)
			continue
		return picked
	return {}

func _weighted_pick(items: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	for item in items:
		total += max(0.0001, float((item as Dictionary).get("score", 0.0)))
	if total <= 0.0:
		return items[0] as Dictionary
	var roll := rng.randf() * total
	var running := 0.0
	for item in items:
		running += max(0.0001, float((item as Dictionary).get("score", 0.0)))
		if roll <= running:
			return item as Dictionary
	return items[items.size() - 1] as Dictionary

func _rng_for(seed: int, key: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = Rand.splitmix64(seed ^ _fnv1a_64(key))
	return rng

func _fnv1a_64(text: String) -> int:
	var hash: int = -3750763034362895579
	var prime: int = 1099511628211
	for b in text.to_utf8_buffer():
		hash = int(hash ^ b) & -1
		hash = int(hash * prime) & -1
	return hash
