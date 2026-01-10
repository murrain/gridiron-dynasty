extends RefCounted
class_name CollegeRecruiting

func run(
	recruits: Array,
	colleges: Array,
	config: Dictionary,
	positions_cfg: Dictionary,
	stats_cfg: Dictionary,
	class_rules: Dictionary,
	scouts_cfg: Dictionary,
	seed: int,
	year: int
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

	var baseline_scores := _baseline_scores(recruits, positions_cfg, class_rules)
	var offers_by_player := {}
	var boards_by_college := {}

	var factory := ScoutFactory.new()
	factory.setup(stats_cfg, scouts_cfg)

	for college in colleges:
		var college_dict: Dictionary = college
		var college_id := String(college_dict.get("id", ""))
		if college_id == "":
			continue
		var college_rng := _rng_for(seed, college_id)
		var scout := factory.create_random_scout("%s Recruiter" % String(college_dict.get("name", "Recruiter")), college_rng)
		var board := _build_board(
			recruits,
			college_dict,
			scout,
			college_rng,
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
		boards_by_college[college_id] = board

		var offer_count := min(offer_limit, board.size())
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

func _build_board(
	recruits: Array,
	college: Dictionary,
	scout: Scout,
	rng: RandomNumberGenerator,
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
	var board: Array = []
	board.resize(recruits.size())
	var college_region := String(college.get("region", ""))
	var college_elite := float(college.get("eliteness", 0.0)) / 100.0

	for i in range(recruits.size()):
		var recruit: Dictionary = recruits[i]
		var player_id := String(recruit.get("player_id", ""))
		var scout_score := scout.score_player(recruit, positions_cfg, stats_cfg, class_rules, rng)
		var base_score := float(baseline_scores.get(player_id, 0.0))
		var combined_rating := (
			scout_score * scout_weight + base_score * baseline_weight
		) / max(0.0001, scout_weight + baseline_weight)
		var rating_norm := clamp(combined_rating / 100.0, 0.0, 1.0)

		var proximity_factor := 1.0
		var home_region := String(recruit.get("home_region", ""))
		if home_region != "" and home_region == college_region:
			var bias := float(recruit.get("proximity_bias", 0.0))
			proximity_factor = 1.0 + (region_match_multiplier - 1.0) * bias

		var score := rating_norm * rating_weight
		score += college_elite * eliteness_weight
		score += proximity_factor * proximity_weight

		if visit_chance > 0.0 and rng.randf() < visit_chance:
			score *= (1.0 + visit_bonus)

		board[i] = {
			"player_id": player_id,
			"score": score,
			"scout_score": scout_score,
			"base_score": base_score
		}

	board.sort_custom(func(a, b):
		var av := float((a as Dictionary).get("score", 0.0))
		var bv := float((b as Dictionary).get("score", 0.0))
		if av == bv:
			return String((a as Dictionary).get("player_id", "")) < String((b as Dictionary).get("player_id", ""))
		return av > bv
	)

	if board_limit > 0 and board.size() > board_limit:
		board = board.slice(0, board_limit)
	return board

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
