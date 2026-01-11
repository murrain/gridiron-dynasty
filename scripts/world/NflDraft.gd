extends RefCounted
class_name NflDraft

const Rand = preload("res://autoloads/Rand.gd")
const ScoutFactory = preload("res://scripts/generation/ScoutFactory.gd")
const ScoutRuntime = preload("res://scripts/core/scouting/ScoutRuntime.gd")
const RecruitingScoreCache = preload("res://scripts/core/scouting/RecruitingScoreCache.gd")
const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")

## Runs the NFL draft for a given year.
##
## Iterates through all rounds, with each team selecting the best available
## player based on scout ratings weighted by positional needs.
##
## Returns:
##   - picks: Array of all draft picks made
##   - undrafted_count: Number of remaining undrafted players
##   - step_seeds: Dictionary of seeds used for determinism tracking
func run(
	world_state: Dictionary,
	year: int,
	seed: int,
	league_cfg: Dictionary,
	positions_cfg: Dictionary,
	stats_cfg: Dictionary,
	scouts_cfg: Dictionary,
	main_cfg: Dictionary
) -> Dictionary:
	var draft_pool_all: Dictionary = world_state.get("draft_pool", {}) as Dictionary
	var draft_pool: Array = draft_pool_all.get(year, []) as Array
	var teams: Array = world_state.get("nfl_teams", []) as Array
	var rosters: Dictionary = world_state.get("nfl_rosters", {}) as Dictionary

	if draft_pool.is_empty() or teams.is_empty():
		return {
			"year": year,
			"picks": [],
			"undrafted_count": draft_pool.size(),
			"step_seeds": {}
		}

	var draft_cfg: Dictionary = league_cfg.get("draft", {}) as Dictionary
	var rounds := int(draft_cfg.get("rounds", 7))
	var picks_per_round := int(draft_cfg.get("picks_per_round", teams.size()))

	# Initialize RNGs for different phases
	var scout_rng := RandomNumberGenerator.new()
	scout_rng.seed = Rand.splitmix64(seed ^ 0xD4AF7001)
	var pick_rng := RandomNumberGenerator.new()
	pick_rng.seed = Rand.splitmix64(seed ^ 0xD4AF7002)
	var contract_rng := RandomNumberGenerator.new()
	contract_rng.seed = Rand.splitmix64(seed ^ 0xD4AF7003)

	# Build team index and initialize rosters
	var team_index := _build_team_index(teams)
	for team in teams:
		var team_id := String(team.get("id", ""))
		if not rosters.has(team_id):
			rosters[team_id] = {
				"players": [],
				"by_position": {}
			}

	# Generate scouts for each team
	var team_scouts := _generate_team_scouts(teams, stats_cfg, scouts_cfg, scout_rng)

	# Sort teams by draft order for each round
	var sorted_teams := _sort_by_draft_order(teams)

	var picks: Array = []
	var remaining_pool := draft_pool.duplicate()
	var class_rules: Dictionary = main_cfg.get("class_rules", {}) as Dictionary

	# OPTIMIZATION: Pre-sort entire draft pool by talent ("the big board")
	# Sort once at start, then players are removed as drafted
	# This eliminates redundant sorting on every pick
	remaining_pool.sort_custom(func(a, b):
		var a_rating := PlayerRatingCalculator.calculate_overall_rating(
			a as Dictionary, positions_cfg, class_rules
		)
		var b_rating := PlayerRatingCalculator.calculate_overall_rating(
			b as Dictionary, positions_cfg, class_rules
		)
		return a_rating > b_rating
	)

	# Scout evaluation cache for the entire draft
	# Cache is shared across all rounds/teams since player states don't change during draft
	# Uses RecruitingScoreCache for year-scoped, deterministic caching
	var score_cache := RecruitingScoreCache.new(year)

	# Execute each round
	for round_num in range(1, rounds + 1):
		if remaining_pool.is_empty():
			break

		for team in sorted_teams:
			if remaining_pool.is_empty():
				break

			var team_id := String(team.get("id", ""))
			var roster: Dictionary = rosters.get(team_id, {}) as Dictionary
			var scout: Dictionary = team_scouts.get(team_id, {}) as Dictionary

			# Score all remaining players (with caching)
			var scored_players := _score_draft_pool(
				remaining_pool,
				roster,
				team_id,
				scout,
				positions_cfg,
				stats_cfg,
				class_rules,
				round_num,
				seed,
				score_cache
			)

			if scored_players.is_empty():
				continue

			# Select best player
			var selected: Dictionary = scored_players[0]
			var player: Dictionary = selected.get("player", {}) as Dictionary
			var player_id := String(player.get("player_id", ""))

			# Create rookie contract
			var overall_pick := picks.size() + 1
			var contract := _create_rookie_contract(round_num, overall_pick, league_cfg, contract_rng)

			# Update player with NFL info
			player["nfl_team_id"] = team_id
			player["nfl_status"] = "active"
			player["contract"] = contract
			player["draft_info"] = {
				"year": year,
				"round": round_num,
				"pick": overall_pick,
				"team_id": team_id
			}

			# Add to roster
			var players: Array = roster.get("players", []) as Array
			players.append(player)
			roster["players"] = players
			_update_roster_by_position(roster, player)
			rosters[team_id] = roster

			# Record pick
			var pick_record := {
				"round": round_num,
				"pick": overall_pick,
				"team_id": team_id,
				"player_id": player_id,
				"position": String(player.get("position", "")),
				"score": float(selected.get("score", 0.0))
			}
			picks.append(pick_record)

			# Remove from pool
			remaining_pool = remaining_pool.filter(func(p):
				return String((p as Dictionary).get("player_id", "")) != player_id
			)

	# Store undrafted players
	var undrafted_pool: Dictionary = world_state.get("undrafted_pool", {}) as Dictionary
	undrafted_pool[year] = remaining_pool
	world_state["undrafted_pool"] = undrafted_pool
	world_state["nfl_rosters"] = rosters

	# Store draft history (D5.1, D5.5)
	# Records all picks with complete information for historical tracking
	# Includes trade tracking fields (traded, original_team_id) for future trade system
	#
	# RNG Note: Draft history recording is deterministic and does not consume RNG.
	# It only reads and records the results of the draft execution above.
	var draft_history: Dictionary = world_state.get("draft_history", {}) as Dictionary
	draft_history[year] = []

	# Build player lookup index for efficient college extraction
	# Maps player_id -> player dictionary from rosters
	var player_lookup := {}
	for team_id in rosters.keys():
		var roster: Dictionary = rosters.get(team_id, {}) as Dictionary
		var roster_players: Array = roster.get("players", []) as Array
		for roster_player in roster_players:
			var rp: Dictionary = roster_player as Dictionary
			var pid := String(rp.get("player_id", ""))
			if pid != "":
				player_lookup[pid] = rp

	# Record each pick with full information
	for pick in picks:
		var p: Dictionary = pick as Dictionary
		var player_id := String(p.get("player_id", ""))
		var team_id := String(p.get("team_id", ""))

		# Extract college from player record (O(1) lookup instead of O(n) search)
		var player_college := ""
		if player_lookup.has(player_id):
			var player_record: Dictionary = player_lookup[player_id] as Dictionary
			player_college = String(player_record.get("college_team_id", ""))

		draft_history[year].append({
			"pick_number": int(p.get("pick", 0)),
			"round": int(p.get("round", 0)),
			"team_id": team_id,
			"player_id": player_id,
			"position": String(p.get("position", "")),
			"college": player_college,
			"traded": false,  # Phase 1: always false (no trade system yet)
			"original_team_id": null  # Phase 1: always null (no trade system yet)
		})
	world_state["draft_history"] = draft_history

	return {
		"year": year,
		"picks": picks,
		"picks_count": picks.size(),
		"undrafted_count": remaining_pool.size(),
		"step_seeds": {
			"scout": scout_rng.seed,
			"pick": pick_rng.seed,
			"contract": contract_rng.seed
		}
	}


func _build_team_index(teams: Array) -> Dictionary:
	var index := {}
	for team in teams:
		var t: Dictionary = team
		var team_id := String(t.get("id", ""))
		if team_id != "":
			index[team_id] = t
	return index


func _generate_team_scouts(
	teams: Array,
	stats_cfg: Dictionary,
	scouts_cfg: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var team_scouts := {}
	var national_scouts: Array = scouts_cfg.get("national_scouts", []) as Array

	for team in teams:
		var t: Dictionary = team
		var team_id := String(t.get("id", ""))
		if team_id == "":
			continue

		# Use a national scout as template, with some variation
		if national_scouts.is_empty():
			team_scouts[team_id] = _default_scout()
		else:
			var scout_idx := rng.randi_range(0, national_scouts.size() - 1)
			var base_scout: Dictionary = (national_scouts[scout_idx] as Dictionary).duplicate(true)
			# Add slight variation for team-specific preferences
			_apply_team_scout_variation(base_scout, rng)
			team_scouts[team_id] = base_scout

	return team_scouts


func _default_scout() -> Dictionary:
	return {
		"base_skill": 0.55,
		"overrate_athletes": 0.0,
		"tape_grinder": 0.25,
		"risk_aversion": 0.10,
		"stat_skill": {},
		"valuation_multipliers": {},
		"estimation_multipliers": {}
	}


func _apply_team_scout_variation(scout: Dictionary, rng: RandomNumberGenerator) -> void:
	# Slight random variation in base_skill
	var base_skill := float(scout.get("base_skill", 0.55))
	scout["base_skill"] = clamp(base_skill + rng.randf_range(-0.05, 0.05), 0.3, 0.9)


func _sort_by_draft_order(teams: Array) -> Array:
	var sorted := teams.duplicate()
	sorted.sort_custom(func(a, b):
		return int((a as Dictionary).get("draft_order", 999)) < int((b as Dictionary).get("draft_order", 999))
	)
	return sorted


func _score_draft_pool(
	pool: Array,
	roster: Dictionary,
	team_id: String,
	scout: Dictionary,
	positions_cfg: Dictionary,
	stats_cfg: Dictionary,
	class_rules: Dictionary,
	round_num: int,
	base_seed: int,
	score_cache: RecruitingScoreCache
) -> Array:
	var needs := _calculate_position_needs(roster, positions_cfg)

	# OPTIMIZATION: Identify positions with any need (need_mult >= 0.95)
	var positions_with_need: Array = []
	for pos in needs.keys():
		if needs[pos] >= 0.95:  # Any position with at least some need
			positions_with_need.append(pos)

	# OPTIMIZATION: Pool is already sorted by talent from run() pre-sort
	# Take top 12-16 players from positions with need
	# This simulates real NFL draft boards where teams focus on top prospects
	# in positions they need rather than evaluating all 500+ players
	var candidates: Array = []
	var max_candidates := 14  # Core evaluation group

	for player in pool:
		var p: Dictionary = player
		var position := String(p.get("position", ""))
		if position in positions_with_need:
			candidates.append(p)
			if candidates.size() >= max_candidates:
				break

	# Fallback: If not enough candidates in needed positions, expand to all positions
	# (happens when roster is nearly full)
	if candidates.size() < 8:
		for player in pool:
			var p: Dictionary = player
			if p not in candidates:
				candidates.append(p)
				if candidates.size() >= max_candidates:
					break

	# HIDDEN GEM MECHANISM: Scout 2-3 additional players outside the consensus
	# This simulates teams finding late-round steals based on film study,
	# athletic traits, or specific scheme fits
	var hidden_gem_count := 2 if round_num <= 4 else 3  # More deep dives in later rounds
	var gems_added := 0
	var search_start := max_candidates  # Start looking after the consensus top players

	for i in range(search_start, min(search_start + 30, pool.size())):
		if gems_added >= hidden_gem_count:
			break
		var p: Dictionary = pool[i]
		var position := String(p.get("position", ""))
		# Look for gems in positions with any need
		if position in positions_with_need and p not in candidates:
			candidates.append(p)
			gems_added += 1

	# NOW run detailed scout evaluation on only these 12-16 candidates
	# Before: 100,000 evaluations per draft
	# After: 224 picks × 14 players = 3,136 evaluations per draft (97% reduction)
	var scored: Array = []
	var phase := "draft_round_%d" % round_num

	for player in candidates:
		var p: Dictionary = player
		var position := String(p.get("position", ""))

		# Detailed team-specific scout evaluation
		var base_score := score_cache.get_or_compute(
			p,
			scout,
			team_id,
			phase,
			positions_cfg,
			stats_cfg,
			class_rules,
			base_seed
		)

		# Apply position need weighting
		var need_mult := float(needs.get(position, 1.0))
		var weighted_score := base_score * need_mult

		scored.append({
			"player": p,
			"score": weighted_score,
			"base_score": base_score,
			"need_mult": need_mult
		})

	# Sort by weighted score descending
	scored.sort_custom(func(a, b):
		return float((a as Dictionary).get("score", 0.0)) > float((b as Dictionary).get("score", 0.0))
	)

	return scored


func _calculate_position_needs(roster: Dictionary, positions_cfg: Dictionary) -> Dictionary:
	var by_position: Dictionary = roster.get("by_position", {}) as Dictionary
	var needs := {}

	# Define ideal roster composition per position
	var ideal_counts := {
		"QB": 3,
		"RB": 4,
		"WR": 6,
		"TE": 3,
		"OL": 9,
		"DL": 6,
		"EDGE": 4,
		"LB": 6,
		"CB": 5,
		"S": 4,
		"K": 1,
		"P": 1
	}

	for pos in positions_cfg.keys():
		var current_count := (by_position.get(pos, []) as Array).size()
		var ideal := int(ideal_counts.get(pos, 2))

		# More need = higher multiplier
		if current_count == 0:
			needs[pos] = 1.5  # High need
		elif current_count < ideal:
			var deficit := ideal - current_count
			needs[pos] = 1.0 + (float(deficit) / float(ideal)) * 0.3
		else:
			needs[pos] = 0.85  # Low need, slight penalty

	return needs


func _update_roster_by_position(roster: Dictionary, player: Dictionary) -> void:
	var by_position: Dictionary = roster.get("by_position", {}) as Dictionary
	var position := String(player.get("position", ""))
	var player_id := String(player.get("player_id", ""))

	if position == "":
		return

	if not by_position.has(position):
		by_position[position] = []

	(by_position[position] as Array).append(player_id)
	roster["by_position"] = by_position


func _create_rookie_contract(
	round_num: int,
	overall_pick: int,
	league_cfg: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	# Rookie contracts are typically 4 years with 5th year option for 1st round
	var years := 4
	var has_fifth_year_option := (round_num == 1)

	# Base salary scales with draft position
	var cap_limit := float(league_cfg.get("cap_limit", 200.0))
	var base_salary := _calculate_rookie_salary(overall_pick, cap_limit)

	# Signing bonus decreases by round
	var signing_bonus := base_salary * (0.8 - (float(round_num - 1) * 0.1))
	signing_bonus = max(signing_bonus, 0.1)

	return {
		"type": "rookie",
		"years_total": years,
		"years_remaining": years,
		"base_salary": base_salary,
		"signing_bonus": signing_bonus,
		"cap_hit": base_salary + (signing_bonus / float(years)),
		"fifth_year_option": has_fifth_year_option,
		"gtd_remaining": signing_bonus
	}


func _calculate_rookie_salary(overall_pick: int, cap_limit: float) -> float:
	# Salary slot values decrease with pick number
	# First overall gets roughly 5% of cap, scaling down
	var max_rookie_pct := 0.05
	var min_rookie_pct := 0.002

	# Exponential decay based on pick
	var decay := pow(0.97, float(overall_pick - 1))
	var pct := max_rookie_pct * decay
	pct = clamp(pct, min_rookie_pct, max_rookie_pct)

	return cap_limit * pct
