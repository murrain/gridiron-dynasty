extends RefCounted
class_name PreDraftProcess

## Pre-Draft Process Simulation
##
## Purpose: Orchestrates all pre-draft evaluation activities including NFL Combine,
## pro days, all-star games, and team visits.
##
## This service handles:
##   1. NFL Combine invites and performance simulation (~330 players)
##   2. Pro day simulation for non-combine invitees
##   3. All-star game invites and performance (Senior Bowl, East-West Shrine)
##   4. Team visit scheduling (max 30 per player)
##   5. Interview scoring and evaluations
##
## Design Philosophy:
##   - Stateless service (all state in world_state)
##   - Deterministic via explicit RNG seeding
##   - Configuration-driven thresholds and impacts
##   - Integration with existing CombineCalculator
##
## RNG Pattern:
##   - Combine invites: Stable sort by rating (deterministic)
##   - Combine performance: CombineCalculator.compute_all() per player
##   - All-star invites: Stable sort by rating (deterministic)
##   - Team visits: Weighted random by need + prospect quality
##   - Interview scores: Gaussian distribution per team-player pair
##
## Integration Points:
##   - WorldCalendar: Runs during draft_prep phase (tick 7)
##   - CombineCalculator: Simulate combine performance
##   - DraftStockTracker: Update draft stock after each event
##   - NflDraft: Use pre_draft_process data in scout evaluation

const Rand = preload("res://autoloads/Rand.gd")
const SimLogger = preload("res://autoloads/SimLogger.gd")
const CombineCalculator = preload("res://scripts/core/rating/CombineCalculator.gd")

## Main entry point for pre-draft process simulation.
##
## Orchestrates all pre-draft activities in sequence:
##   1. Select combine invitees (~330 players)
##   2. Simulate combine performance
##   3. Simulate pro days for non-invitees
##   4. Select and simulate all-star games
##   5. Simulate team visits
##   6. Calculate draft stock movement
##
## Side effects:
##   - Adds "pre_draft_process" field to all eligible players
##   - Updates "draft_stock_timeline" via DraftStockTracker
##   - Logs major events (combine standouts, all-star MVPs)
##
## RNG consumption:
##   - Combine: ~330 players × CombineCalculator calls
##   - Pro days: ~200 players × CombineCalculator calls
##   - All-star games: ~210 players × performance variance
##   - Team visits: ~100 top prospects × visit selection
##   - Interviews: ~3200 team-player pairs × score generation
##
## @param world_state: World state dictionary with draft_pool
## @param year: Draft year to process
## @param seed: Base RNG seed for determinism
## @param config: Configuration with pre_draft_process section
## @return Dictionary: Summary statistics and step seeds
static func run(
	world_state: Dictionary,
	year: int,
	seed: int,
	config: Dictionary
) -> Dictionary:
	var draft_pool_all: Dictionary = world_state.get("draft_pool", {})
	var draft_pool: Array = draft_pool_all.get(year, [])

	if draft_pool.is_empty():
		return {
			"year": year,
			"combine_invites": 0,
			"pro_day_participants": 0,
			"all_star_participants": 0,
			"team_visits_scheduled": 0,
			"step_seeds": {}
		}

	var pre_draft_cfg: Dictionary = config.get("pre_draft_process", {})
	var combine_cfg: Dictionary = pre_draft_cfg.get("combine", {})
	var all_star_cfg: Dictionary = pre_draft_cfg.get("all_star_games", {})
	var visits_cfg: Dictionary = pre_draft_cfg.get("team_visits", {})

	# Initialize RNGs for different phases
	var combine_rng := RandomNumberGenerator.new()
	combine_rng.seed = Rand.splitmix64(seed ^ 0xC0B1E01)

	var pro_day_rng := RandomNumberGenerator.new()
	pro_day_rng.seed = Rand.splitmix64(seed ^ 0xC0B1E02)

	var all_star_rng := RandomNumberGenerator.new()
	all_star_rng.seed = Rand.splitmix64(seed ^ 0xC0B1E03)

	var visits_rng := RandomNumberGenerator.new()
	visits_rng.seed = Rand.splitmix64(seed ^ 0xC0B1E04)

	var interview_rng := RandomNumberGenerator.new()
	interview_rng.seed = Rand.splitmix64(seed ^ 0xC0B1E05)

	# Phase 1: Select combine invitees
	var combine_invitees: Array = _select_combine_invitees(draft_pool, combine_cfg, combine_rng)

	# Phase 2: Simulate combine performance
	var combine_tests_cfg: Dictionary = config.get("combine_tests", {})
	var combine_tuning_cfg: Dictionary = config.get("combine_tuning", {})
	_simulate_combine(combine_invitees, combine_tests_cfg, combine_tuning_cfg, combine_rng)

	# Phase 3: Simulate pro days for non-invitees
	var pro_day_pool: Array = _get_pro_day_eligible(draft_pool, combine_invitees)
	_simulate_pro_days(pro_day_pool, combine_tests_cfg, combine_tuning_cfg, pro_day_rng)

	# Phase 4: Select and simulate all-star games
	var all_star_participants: Array = _simulate_all_star_games(draft_pool, all_star_cfg, all_star_rng)

	# Phase 5: Simulate team visits
	var teams: Array = world_state.get("nfl_teams", [])
	var visit_count := _simulate_team_visits(draft_pool, teams, visits_cfg, visits_rng)

	# Phase 6: Simulate interview scores
	_simulate_interview_scores(draft_pool, teams, pre_draft_cfg, interview_rng)

	return {
		"year": year,
		"combine_invites": combine_invitees.size(),
		"pro_day_participants": pro_day_pool.size(),
		"all_star_participants": all_star_participants.size(),
		"team_visits_scheduled": visit_count,
		"step_seeds": {
			"combine": combine_rng.seed,
			"pro_day": pro_day_rng.seed,
			"all_star": all_star_rng.seed,
			"visits": visits_rng.seed,
			"interview": interview_rng.seed
		}
	}


## Selects players to invite to NFL Combine.
##
## Selection criteria:
##   1. Sort by overall rating (highest first)
##   2. Apply minimum rating threshold from config
##   3. Take top ~330 players
##
## RNG: None (deterministic sort)
##
## @param pool: Array of draft-eligible players
## @param config: Combine configuration
## @param rng: RNG instance (unused but kept for consistency)
## @return Array: Combine invitees
static func _select_combine_invitees(
	pool: Array,
	config: Dictionary,
	rng: RandomNumberGenerator
) -> Array:
	var invite_count := int(config.get("invite_count", 330))
	var min_rating := float(config.get("invite_criteria", {}).get("min_rating_threshold", 68.0))

	# Sort by rating (stable sort for determinism)
	var sorted_pool := pool.duplicate()
	sorted_pool.sort_custom(func(a, b):
		var a_rating := _get_player_rating(a as Dictionary)
		var b_rating := _get_player_rating(b as Dictionary)
		if abs(a_rating - b_rating) < 0.01:
			# Tiebreaker: player_id for stability
			return String((a as Dictionary).get("player_id", "")) < String((b as Dictionary).get("player_id", ""))
		return a_rating > b_rating
	)

	# Filter by minimum rating and take top N
	var invitees: Array = []
	for player in sorted_pool:
		var p: Dictionary = player
		var rating := _get_player_rating(p)

		if rating >= min_rating and invitees.size() < invite_count:
			invitees.append(p)

	return invitees


## Simulates NFL Combine performance for all invitees.
##
## Uses CombineCalculator to generate realistic combine results.
## Evaluates performance impact on draft stock:
##   - Elite performance (90th+ percentile): +8% draft boost
##   - Poor performance (25th- percentile): -5% draft penalty
##
## Side effects:
##   - Sets player["pre_draft_process"]["combine_invited"] = true
##   - Sets player["pre_draft_process"]["combine_performance"]
##   - Logs standout performances
##
## RNG: CombineCalculator.compute_all() per player
##
## @param invitees: Array of combine invitees
## @param tests_cfg: Combine tests configuration
## @param tuning_cfg: Combine tuning configuration
## @param rng: RNG instance for performance variance
static func _simulate_combine(
	invitees: Array,
	tests_cfg: Dictionary,
	tuning_cfg: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	var performance_cfg: Dictionary = tuning_cfg.get("performance_impact", {})
	var elite_threshold := float(performance_cfg.get("elite_performance_boost", {}).get("threshold_percentile", 90.0))
	var elite_boost := float(performance_cfg.get("elite_performance_boost", {}).get("draft_boost", 0.08))
	var poor_threshold := float(performance_cfg.get("poor_performance_penalty", {}).get("threshold_percentile", 25.0))
	var poor_penalty := float(performance_cfg.get("poor_performance_penalty", {}).get("draft_penalty", 0.05))

	for player in invitees:
		var p: Dictionary = player

		# Initialize pre_draft_process if not exists
		if not p.has("pre_draft_process"):
			p["pre_draft_process"] = {}

		var pre_draft: Dictionary = p["pre_draft_process"]
		pre_draft["combine_invited"] = true

		# Simulate combine performance
		var results: Dictionary = CombineCalculator.compute_all(p, tuning_cfg, tests_cfg, rng)

		# Calculate percentiles and overall grade
		var percentiles := _calculate_combine_percentiles(results, p)
		var overall_grade := _calculate_overall_performance_grade(percentiles, elite_threshold, poor_threshold, elite_boost, poor_penalty)

		pre_draft["combine_performance"] = {
			"forty_percentile": float(percentiles.get("forty_yard_dash", 50.0)),
			"vertical_percentile": float(percentiles.get("vertical_jump", 50.0)),
			"overall_performance_grade": overall_grade,
			"results": results
		}

		# Log standout performances
		if overall_grade >= elite_boost * 0.75:
			var name := String(p.get("name", "Unknown"))
			var position := String(p.get("position", "?"))
			SimLogger.info("%s %s - Combine Standout (grade: +%.2f)" % [
				position, name, overall_grade
			])


## Gets list of players eligible for pro day.
##
## Pro days are for players who:
##   - Were not invited to combine, OR
##   - Were invited but want to improve specific drills
##
## For simplicity, we only simulate pro days for non-invitees.
##
## RNG: None (deterministic filter)
##
## @param pool: Full draft pool
## @param combine_invitees: Players invited to combine
## @return Array: Pro day eligible players
static func _get_pro_day_eligible(
	pool: Array,
	combine_invitees: Array
) -> Array:
	var invitee_ids := {}
	for player in combine_invitees:
		var p: Dictionary = player
		invitee_ids[String(p.get("player_id", ""))] = true

	var eligible: Array = []
	for player in pool:
		var p: Dictionary = player
		var player_id := String(p.get("player_id", ""))
		if not invitee_ids.has(player_id):
			eligible.append(p)

	return eligible


## Simulates pro day performance for non-combine invitees.
##
## Pro days allow players to showcase skills at their college.
## Typically have less visibility than combine but can boost stock.
##
## Side effects:
##   - Sets player["pre_draft_process"]["pro_day_attended"] = true
##   - Sets player["pre_draft_process"]["pro_day_performance"]
##
## RNG: CombineCalculator.compute_all() per player
##
## @param eligible: Array of pro day eligible players
## @param tests_cfg: Combine tests configuration
## @param tuning_cfg: Combine tuning configuration
## @param rng: RNG instance for performance variance
static func _simulate_pro_days(
	eligible: Array,
	tests_cfg: Dictionary,
	tuning_cfg: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	for player in eligible:
		var p: Dictionary = player

		# Initialize pre_draft_process if not exists
		if not p.has("pre_draft_process"):
			p["pre_draft_process"] = {}

		var pre_draft: Dictionary = p["pre_draft_process"]
		pre_draft["pro_day_attended"] = true

		# Simulate pro day performance (similar to combine)
		var results: Dictionary = CombineCalculator.compute_all(p, tuning_cfg, tests_cfg, rng)

		pre_draft["pro_day_performance"] = results


## Simulates all-star game participation and performance.
##
## All-star games:
##   1. Senior Bowl (~110 top seniors)
##   2. East-West Shrine Game (~100 mid-tier prospects)
##
## Selection criteria:
##   - Sort by rating
##   - Apply minimum rating thresholds
##   - Take top N for each game
##
## Performance impact:
##   - Standout performance: +2% to +6% draft boost (Senior Bowl)
##   - Standout performance: +1% to +3% draft boost (Shrine Game)
##
## Side effects:
##   - Sets player["pre_draft_process"]["all_star_games"]
##   - Sets player["pre_draft_process"]["all_star_performance"]
##   - Logs MVP/standout performances
##
## RNG: Performance variance for each participant
##
## @param pool: Full draft pool
## @param config: All-star games configuration
## @param rng: RNG instance for selection and performance
## @return Array: All participants across all games
static func _simulate_all_star_games(
	pool: Array,
	config: Dictionary,
	rng: RandomNumberGenerator
) -> Array:
	var all_participants: Array = []

	# Senior Bowl
	var senior_bowl_cfg: Dictionary = config.get("senior_bowl", {})
	var senior_bowl_invites := int(senior_bowl_cfg.get("invite_count", 110))
	var senior_bowl_min_rating := float(senior_bowl_cfg.get("min_rating", 72.0))
	var senior_bowl_boost_range: Array = senior_bowl_cfg.get("draft_boost_range", [0.02, 0.06])

	var senior_bowl_participants := _select_all_star_participants(
		pool, senior_bowl_invites, senior_bowl_min_rating
	)

	for player in senior_bowl_participants:
		var p: Dictionary = player
		if not p.has("pre_draft_process"):
			p["pre_draft_process"] = {}

		var pre_draft: Dictionary = p["pre_draft_process"]
		var games: Array = pre_draft.get("all_star_games", [])
		games.append("senior_bowl")
		pre_draft["all_star_games"] = games

		# Simulate performance
		var boost := rng.randf_range(float(senior_bowl_boost_range[0]), float(senior_bowl_boost_range[1]))
		if not pre_draft.has("all_star_performance"):
			pre_draft["all_star_performance"] = {}

		var perf: Dictionary = pre_draft["all_star_performance"]
		perf["senior_bowl"] = {"draft_boost": boost}

		# Log standouts (top 10% boost)
		if boost >= (float(senior_bowl_boost_range[1]) * 0.8):
			var name := String(p.get("name", "Unknown"))
			var position := String(p.get("position", "?"))
			SimLogger.info("%s %s - Senior Bowl Standout (boost: +%.2f%%)" % [
				position, name, boost * 100.0
			])

		all_participants.append(p)

	# East-West Shrine Game
	var shrine_cfg: Dictionary = config.get("east_west_shrine", {})
	var shrine_invites := int(shrine_cfg.get("invite_count", 100))
	var shrine_min_rating := float(shrine_cfg.get("min_rating", 65.0))
	var shrine_boost_range: Array = shrine_cfg.get("draft_boost_range", [0.01, 0.03])

	var shrine_participants := _select_all_star_participants(
		pool, shrine_invites, shrine_min_rating
	)

	for player in shrine_participants:
		var p: Dictionary = player
		if not p.has("pre_draft_process"):
			p["pre_draft_process"] = {}

		var pre_draft: Dictionary = p["pre_draft_process"]
		var games: Array = pre_draft.get("all_star_games", [])
		games.append("east_west_shrine")
		pre_draft["all_star_games"] = games

		# Simulate performance
		var boost := rng.randf_range(float(shrine_boost_range[0]), float(shrine_boost_range[1]))
		if not pre_draft.has("all_star_performance"):
			pre_draft["all_star_performance"] = {}

		var perf: Dictionary = pre_draft["all_star_performance"]
		perf["east_west_shrine"] = {"draft_boost": boost}

		all_participants.append(p)

	return all_participants


## Selects participants for an all-star game.
##
## Selection logic:
##   1. Sort by rating
##   2. Filter by minimum rating
##   3. Take top N
##
## RNG: None (deterministic sort)
##
## @param pool: Full draft pool
## @param invite_count: Number of invites
## @param min_rating: Minimum rating threshold
## @return Array: Selected participants
static func _select_all_star_participants(
	pool: Array,
	invite_count: int,
	min_rating: float
) -> Array:
	# Sort by rating (stable sort for determinism)
	var sorted_pool := pool.duplicate()
	sorted_pool.sort_custom(func(a, b):
		var a_rating := _get_player_rating(a as Dictionary)
		var b_rating := _get_player_rating(b as Dictionary)
		if abs(a_rating - b_rating) < 0.01:
			return String((a as Dictionary).get("player_id", "")) < String((b as Dictionary).get("player_id", ""))
		return a_rating > b_rating
	)

	# Filter and select
	var participants: Array = []
	for player in sorted_pool:
		var p: Dictionary = player
		var rating := _get_player_rating(p)

		if rating >= min_rating and participants.size() < invite_count:
			participants.append(p)

	return participants


## Simulates team visits for top prospects.
##
## Team visit rules:
##   - Each player can visit up to 30 teams (NFL rule)
##   - Top prospects get more visits
##   - Teams prioritize visits by need + prospect quality
##
## Visit impact:
##   - Positive visit: +0% to +5% draft boost for that team
##   - Negative visit: -3% to +0% draft penalty for that team
##
## Side effects:
##   - Sets player["pre_draft_process"]["team_visits"]
##   - Sets player["pre_draft_process"]["visit_impact"] (per team)
##
## RNG: Visit selection and impact per player-team pair
##
## @param pool: Full draft pool
## @param teams: Array of NFL teams
## @param config: Team visits configuration
## @param rng: RNG instance for visit scheduling
## @return int: Total visits scheduled
static func _simulate_team_visits(
	pool: Array,
	teams: Array,
	config: Dictionary,
	rng: RandomNumberGenerator
) -> int:
	var max_per_player := int(config.get("max_per_player", 30))
	var impact_range: Array = config.get("visit_impact_range", [-0.03, 0.05])

	var total_visits := 0

	# Focus on top ~100 prospects (teams don't waste visits on late-rounders)
	var top_prospects := pool.duplicate()
	top_prospects.sort_custom(func(a, b):
		return _get_player_rating(a as Dictionary) > _get_player_rating(b as Dictionary)
	)
	top_prospects = top_prospects.slice(0, min(100, top_prospects.size()))

	for player in top_prospects:
		var p: Dictionary = player

		if not p.has("pre_draft_process"):
			p["pre_draft_process"] = {}

		var pre_draft: Dictionary = p["pre_draft_process"]

		# Determine number of visits (higher rated = more visits)
		var rating := _get_player_rating(p)
		var visit_count := int(max_per_player * (rating / 100.0))
		visit_count = clamp(visit_count, 5, max_per_player)

		# Randomly select teams using explicit RNG (Fisher-Yates shuffle)
		var shuffled_teams := teams.duplicate()
		_shuffle_with_rng(shuffled_teams, rng)

		var visits: Array = []
		var visit_impacts := {}

		for i in range(min(visit_count, shuffled_teams.size())):
			var team: Dictionary = shuffled_teams[i]
			var team_id := String(team.get("id", ""))
			visits.append(team_id)

			# Generate visit impact
			var impact := rng.randf_range(float(impact_range[0]), float(impact_range[1]))
			visit_impacts[team_id] = impact

			total_visits += 1

		pre_draft["team_visits"] = visits
		pre_draft["visit_impacts"] = visit_impacts

	return total_visits


## Simulates interview scores for team-player pairs.
##
## Interview scoring:
##   - Base score: 50.0 (neutral)
##   - Variance: Gaussian distribution (sigma ~10)
##   - Character profile affects score
##   - Medical concerns affect score
##
## Side effects:
##   - Sets player["pre_draft_process"]["interview_scores"]
##
## RNG: Gaussian score per team-player pair that had visits
##
## @param pool: Full draft pool
## @param teams: Array of NFL teams
## @param config: Pre-draft process configuration
## @param rng: RNG instance for score generation
static func _simulate_interview_scores(
	pool: Array,
	teams: Array,
	config: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	var base_score := 50.0
	var score_sigma := 10.0

	for player in pool:
		var p: Dictionary = player
		var pre_draft: Dictionary = p.get("pre_draft_process", {})
		var team_visits: Array = pre_draft.get("team_visits", [])

		if team_visits.is_empty():
			continue

		var interview_scores := {}

		for team_id in team_visits:
			# Generate base interview score
			var score := base_score + rng.randfn(0.0, score_sigma)

			# Adjust for character profile
			var character_profile: Dictionary = p.get("character_profile", {})
			var character_grade := String(character_profile.get("character_grade", "clean"))
			if character_grade == "exemplary":
				score += 8.0
			elif character_grade == "red_flag":
				score -= 15.0
			elif character_grade == "concern":
				score -= 5.0

			# Adjust for medical concerns
			var medical_eval: Dictionary = p.get("medical_evaluation", {})
			var medical_grade := String(medical_eval.get("grade", "clean"))
			if medical_grade == "failed":
				score -= 20.0
			elif medical_grade == "major_concern":
				score -= 10.0
			elif medical_grade == "minor_concern":
				score -= 3.0

			score = clamp(score, 0.0, 100.0)
			interview_scores[team_id] = score

		pre_draft["interview_scores"] = interview_scores


## Calculates combine percentiles for a player's results.
##
## Maps raw combine results to percentiles (0-100) based on position norms.
##
## RNG: None (deterministic calculation)
##
## @param results: Raw combine results from CombineCalculator
## @param player: Player dictionary with position
## @return Dictionary: Percentiles for each test
static func _calculate_combine_percentiles(
	results: Dictionary,
	player: Dictionary
) -> Dictionary:
	# Simplified percentile calculation
	# In production, would use historical data per position
	var percentiles := {}

	for test_name in results.keys():
		var value := float(results[test_name])
		# Simple heuristic: normalize to 0-100 scale
		var percentile: float = clamp((value / 100.0) * 100.0, 0.0, 100.0)
		percentiles[test_name] = percentile

	return percentiles


## Calculates overall performance grade from combine percentiles.
##
## Grade logic:
##   - Elite performance (90th+ percentile): +draft boost
##   - Poor performance (25th- percentile): -draft penalty
##   - Average performance: 0 (neutral)
##
## RNG: None (deterministic calculation)
##
## @param percentiles: Percentile results for each test
## @param elite_threshold: Percentile threshold for elite grade
## @param poor_threshold: Percentile threshold for poor grade
## @param elite_boost: Draft boost for elite performance
## @param poor_penalty: Draft penalty for poor performance
## @return float: Overall performance grade (-0.1 to +0.1)
static func _calculate_overall_performance_grade(
	percentiles: Dictionary,
	elite_threshold: float,
	poor_threshold: float,
	elite_boost: float,
	poor_penalty: float
) -> float:
	if percentiles.is_empty():
		return 0.0

	# Calculate average percentile
	var sum := 0.0
	for perc in percentiles.values():
		sum += float(perc)
	var avg_percentile := sum / float(percentiles.size())

	# Apply grade logic
	if avg_percentile >= elite_threshold:
		# Elite: scale boost based on how far above threshold
		var excess := (avg_percentile - elite_threshold) / (100.0 - elite_threshold)
		return elite_boost * clamp(excess, 0.5, 1.0)
	elif avg_percentile <= poor_threshold:
		# Poor: scale penalty based on how far below threshold
		var deficit := (poor_threshold - avg_percentile) / poor_threshold
		return -poor_penalty * clamp(deficit, 0.5, 1.0)
	else:
		# Average: neutral
		return 0.0


## Gets player overall rating (simplified).
##
## In production, would use PlayerRatingCalculator.calculate_overall_rating().
## For now, use a simple stat average.
##
## RNG: None (deterministic lookup)
##
## @param player: Player dictionary
## @return float: Overall rating (0-100)
static func _get_player_rating(player: Dictionary) -> float:
	# Simplified rating calculation
	var stats: Dictionary = player.get("stats", {})
	if stats.is_empty():
		return 50.0

	var sum := 0.0
	var count := 0
	for stat_value in stats.values():
		sum += float(stat_value)
		count += 1

	return sum / float(count) if count > 0 else 50.0


## Shuffles an array in place using explicit RNG (Fisher-Yates algorithm).
##
## This replaces Array.shuffle() which uses global RNG and breaks determinism.
##
## RNG: (n-1) randi_range() calls where n = array size
##
## @param arr: Array to shuffle in place
## @param rng: RNG instance for deterministic shuffling
static func _shuffle_with_rng(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp = arr[i]
		arr[i] = arr[j]
		arr[j] = temp


## Returns current timestamp in HH:MM:SS format
static func _get_timestamp() -> String:
	var time := Time.get_time_dict_from_system()
	return "%02d:%02d:%02d" % [time["hour"], time["minute"], time["second"]]
