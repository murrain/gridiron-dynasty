extends RefCounted
class_name NflDraft

const Rand = preload("res://autoloads/Rand.gd")
const SimLogger = preload("res://autoloads/SimLogger.gd")
const ScoutFactory = preload("res://scripts/generation/ScoutFactory.gd")
const ScoutRuntime = preload("res://scripts/core/scouting/ScoutRuntime.gd")
const RecruitingScoreCache = preload("res://scripts/core/scouting/RecruitingScoreCache.gd")
const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")
const RosterComposition = preload("res://scripts/core/roster/RosterComposition.gd")

const ELITE_RESCUE_SCORE := 999.0  # Guaranteed top pick priority for elite prospects

## Runs the NFL draft for a given year.
##
## Iterates through all rounds, with each team selecting the best available
## player based on scout ratings weighted by positional needs.
##
## Side effects:
##   - Caches team scouting quality in world_state["nfl_scouting_quality"] on first run
##   - This cached data persists across multiple draft runs for consistency
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

	# Initialize draft pick ownership ledger if not present
	# This enables pick trading by tracking who owns each pick
	if not world_state.has("draft_pick_ownership"):
		initialize_pick_ownership(world_state, teams, year, rounds)

	# Initialize team scouting quality (once per world, cached)
	if not world_state.has("nfl_scouting_quality"):
		world_state["nfl_scouting_quality"] = _generate_team_scouting_quality(
			teams, main_cfg.get("class_rules", {}), seed
		)
	var team_quality: Dictionary = world_state.get("nfl_scouting_quality", {})

	# Build team index and initialize rosters
	var team_index := _build_team_index(teams)
	for team in teams:
		var team_id := String(team.get("id", ""))
		if not rosters.has(team_id):
			rosters[team_id] = {
				"players": [],
				"by_position": {}
			}

	# Generate scouts for each team with quality modifiers
	var team_scouts := _generate_team_scouts(teams, stats_cfg, scouts_cfg, scout_rng, team_quality)

	# Sort teams by draft order for each round
	var sorted_teams := _sort_by_draft_order(teams, world_state, year)

	var picks: Array = []
	var remaining_pool := draft_pool.duplicate()
	var class_rules: Dictionary = main_cfg.get("class_rules", {}) as Dictionary

	# Normalize field names early: draft uses "player_id", FA expects "id"
	# This ensures UDFAs are compatible with FreeAgency system from the start
	for player in remaining_pool:
		var p: Dictionary = player
		if p.has("player_id") and not p.has("id"):
			p["id"] = p["player_id"]

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

	# Get draft pick ownership ledger
	var ownership: Dictionary = world_state.get("draft_pick_ownership", {}) as Dictionary

	# Calculate compensatory picks for this draft year
	# These are awarded based on previous year's FA losses
	var comp_picks := calculate_compensatory_picks(world_state, year, league_cfg)

	# Execute each round
	for round_num in range(1, rounds + 1):
		if remaining_pool.is_empty():
			break

		# Resolve pick order for this round (respects ownership/trades)
		var round_picks := resolve_draft_order_with_ownership(
			sorted_teams, ownership, year, round_num
		)

		# Insert compensatory picks at end of round
		round_picks = insert_compensatory_picks(
			round_picks, comp_picks, year, round_num, world_state
		)

		for pick_assignment in round_picks:
			if remaining_pool.is_empty():
				break

			var assignment: Dictionary = pick_assignment as Dictionary
			var original_team_id := String(assignment.get("original_team_id", ""))
			var team_id := String(assignment.get("current_owner_id", ""))
			var is_traded := bool(assignment.get("traded", false))
			var is_compensatory := bool(assignment.get("compensatory", false))

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
				score_cache,
				year
			)

			if scored_players.is_empty():
				continue

			# Select best player
			var selected: Dictionary = scored_players[0]
			var player: Dictionary = selected.get("player", {}) as Dictionary
			var player_id := String(player.get("player_id", ""))

			# Create rookie contract
			var overall_pick := picks.size() + 1
			var contract := _create_rookie_contract(round_num, overall_pick, league_cfg, contract_rng, year)

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

			# Flatten draft_year for RosterManagement compatibility
			player["draft_year"] = year

			# Initialize eval_score using composite_score for RosterManagement
			var composite := float(player.get("composite_score", 50.0))
			player["eval_score"] = composite

			# Add to roster
			var players: Array = roster.get("players", []) as Array
			players.append(player)
			roster["players"] = players
			_update_roster_by_position(roster, player)
			rosters[team_id] = roster

			# Check if position is overstocked and release weakest player if needed
			_handle_post_draft_roster_cuts(
				world_state,
				roster,
				team_id,
				String(player.get("position", "")),
				year,
				positions_cfg
			)

			# Record pick
			var pick_record := {
				"round": round_num,
				"pick": overall_pick,
				"team_id": team_id,
				"player_id": player_id,
				"position": String(player.get("position", "")),
				"score": float(selected.get("score", 0.0)),
				"traded": is_traded,
				"original_team_id": original_team_id if is_traded else null,
				"compensatory": is_compensatory
			}
			picks.append(pick_record)

			# Log Round 1 picks with alternatives for visibility
			if round_num == 1:
				# Temporarily annotate scored_players with draft_score for sorting
				var pool_with_scores: Array = []
				for sp in scored_players:
					var sp_dict: Dictionary = sp
					var sp_player: Dictionary = sp_dict.get("player", {})
					var sp_copy: Dictionary = sp_player.duplicate(false)
					sp_copy["draft_score"] = float(sp_dict.get("score", 0.0))
					pool_with_scores.append(sp_copy)

				var top_alternatives: Array = _get_top_alternatives(pool_with_scores, 3, player_id)
				var alt_text: String = ""
				if top_alternatives.size() >= 2:
					var second: Dictionary = top_alternatives[0]
					var third: Dictionary = top_alternatives[1]
					alt_text = " (2nd: %s %s, 3rd: %s %s)" % [
						String(second.get("position", "?")),
						String(second.get("name", "Unknown")),
						String(third.get("position", "?")),
						String(third.get("name", "Unknown"))
					]

				SimLogger.info("Pick %d (%s): %s %s%s" % [
					overall_pick,
					team_id,
					String(player.get("position", "?")),
					String(player.get("name", "Unknown")),
					alt_text
				])

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
	# Includes trade tracking fields (traded, original_team_id) for pick trading system
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
		var is_traded := bool(p.get("traded", false))
		var original_team_id: Variant = p.get("original_team_id", null)
		var is_compensatory := bool(p.get("compensatory", false))

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
			"traded": is_traded,
			"original_team_id": original_team_id,
			"compensatory": is_compensatory
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


## Generates persistent team scouting quality metrics.
##
## Quality determines scout skill (higher = better board accuracy) and
## board noise (higher = more variance in evaluations). Each team is assigned
## to a tier (elite/good/average/poor/terrible) based on configuration, then
## small jitter is added for deterministic variance.
##
## RNG consumption pattern:
## - 1 randf_range() call per team (for base_quality jitter)
##
## Parameters:
##   teams: Array of team dictionaries with "id" fields
##   class_rules: Configuration dictionary with "draft_team_quality" section
##   world_seed: Seed used for deterministic generation (hashed with team_id)
##
## Returns:
##   Dictionary mapping team_id -> {
##     base_quality: float (0.0-1.0),
##     noise_modifier: float (multiplier for board_noise_sigma),
##     skill_modifier: float (multiplier for base_skill),
##     tier: String (quality tier name)
##   }
static func _generate_team_scouting_quality(
	teams: Array,
	class_rules: Dictionary,
	world_seed: int
) -> Dictionary:
	var quality_cfg: Dictionary = class_rules.get("draft_team_quality", {})

	# If disabled, return neutral quality for all teams
	if not bool(quality_cfg.get("enabled", true)):
		var neutral := {}
		for team in teams:
			var t: Dictionary = team
			neutral[String(t.get("id", ""))] = {
				"base_quality": 0.50,
				"noise_modifier": 1.0,
				"skill_modifier": 1.0,
				"tier": "average"
			}
		return neutral

	var tiers: Dictionary = quality_cfg.get("quality_tiers", {})
	var quality_map := {}

	# Build tier lookup: team_id -> tier_name
	var team_to_tier := {}
	for tier_name in tiers.keys():
		var tier: Dictionary = tiers[tier_name]
		var team_list: Array = tier.get("teams", [])
		for tm in team_list:
			team_to_tier[String(tm)] = tier_name

	# Assign quality with deterministic jitter to avoid exact ties
	for team in teams:
		var t: Dictionary = team
		var team_id := String(t.get("id", ""))
		var tier_name := String(team_to_tier.get(team_id, "average"))
		var tier: Dictionary = tiers.get(tier_name, {})

		# Create team-specific RNG from world_seed XOR team_id hash
		# This ensures same seed + team always produces same quality
		var team_rng := RandomNumberGenerator.new()
		team_rng.seed = Rand.splitmix64(world_seed ^ hash(team_id))

		# Extract tier base values
		var base := float(tier.get("base_quality", 0.50))
		var noise := float(tier.get("noise_modifier", 1.0))
		var skill := float(tier.get("skill_modifier", 1.0))

		# Add small jitter to base_quality for variance within tier
		# RNG consumption: 1 randf_range() per team
		base += team_rng.randf_range(-0.05, 0.05)
		base = clamp(base, 0.2, 0.9)

		quality_map[team_id] = {
			"base_quality": base,
			"noise_modifier": noise,
			"skill_modifier": skill,
			"tier": tier_name
		}

	return quality_map


## Generates scouts for each NFL team with team-specific quality modifiers.
##
## Applies team scouting quality to scout attributes:
## - skill_modifier: Multiplies base_skill (better teams have more accurate scouts)
## - noise_modifier: Multiplies board_noise_sigma (better teams have less noise)
## - base_quality: If > 0.65, increases tape_grinder trait (elite teams favor film study)
##
## RNG consumption pattern:
## - 1 randi_range() call per team (selecting national scout template)
## - 1 randf_range() call per team (base_skill variation in _apply_team_scout_variation)
## - 1 randf_range() call per elite team (tape_grinder bonus if base_quality > 0.65)
##
## Parameters:
##   teams: Array of team dictionaries with "id" fields
##   stats_cfg: Stats configuration dictionary (unused but kept for consistency)
##   scouts_cfg: Scout configuration with "national_scouts" array
##   rng: RNG instance for deterministic scout generation
##   team_quality: Dictionary mapping team_id -> quality metrics from _generate_team_scouting_quality()
##
## Returns:
##   Dictionary mapping team_id -> scout dictionary with quality-modified attributes
func _generate_team_scouts(
	teams: Array,
	stats_cfg: Dictionary,
	scouts_cfg: Dictionary,
	rng: RandomNumberGenerator,
	team_quality: Dictionary
) -> Dictionary:
	var team_scouts := {}
	var national_scouts: Array = scouts_cfg.get("national_scouts", []) as Array

	for team in teams:
		var t: Dictionary = team
		var team_id := String(t.get("id", ""))
		if team_id == "":
			continue

		# Use a national scout as template, with some variation
		# RNG: Consumes 1 randi_range() call to select scout template
		var base_scout: Dictionary
		if national_scouts.is_empty():
			base_scout = _default_scout()
		else:
			var scout_idx := rng.randi_range(0, national_scouts.size() - 1)
			base_scout = (national_scouts[scout_idx] as Dictionary).duplicate(true)

		# Add slight variation for team-specific preferences
		# RNG: Consumes 1 randf_range() call for base_skill variation
		_apply_team_scout_variation(base_scout, rng)

		# Apply team quality modifiers (Phase 4 integration)
		# This connects the cached team_quality from Phase 1 to actual scout attributes
		var quality: Dictionary = team_quality.get(team_id, {})
		if not quality.is_empty():
			_apply_team_quality_to_scout(base_scout, quality, rng)

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
	# RNG: Consumes 1 randf_range() call
	var base_skill := float(scout.get("base_skill", 0.55))
	scout["base_skill"] = clamp(base_skill + rng.randf_range(-0.05, 0.05), 0.3, 0.9)


## Applies team scouting quality modifiers to a scout's attributes.
##
## Modifies three core scout attributes based on team quality:
##
## 1. **base_skill**: Multiplied by skill_modifier, clamped to [0.3, 0.9]
##    - Elite teams (BAL: 1.15x): Better talent evaluation accuracy
##    - Terrible teams (CLE: 0.85x): Worse talent evaluation accuracy
##    - Example: 0.55 base_skill * 1.15 (BAL) = 0.6325 → More accurate boards
##
## 2. **board_noise_sigma**: Multiplied by noise_modifier, clamped to [0.8, 3.5]
##    - Elite teams (BAL: 0.80x): Less variance in evaluations (consensus)
##    - Terrible teams (CLE: 1.35x): More variance in evaluations (disagreement)
##    - Example: 1.8 sigma * 0.80 (BAL) = 1.44 → Tighter rating distributions
##
## 3. **tape_grinder**: Increased by 0.05-0.15 if base_quality > 0.65 (elite teams only)
##    - Elite teams emphasize film study over raw athleticism
##    - RNG: Consumes 1 randf_range() call for elite teams only
##    - Example: 0.25 tape_grinder + 0.10 (elite bonus) = 0.35 → More film-focused
##
## Quality tier examples:
## - Ravens (elite): skill=1.15x, noise=0.80x, tape_grinder+0.10 → Superior scouting
## - Browns (terrible): skill=0.85x, noise=1.35x, no tape bonus → Inferior scouting
##
## RNG consumption pattern:
## - 0 calls for non-elite teams (base_quality <= 0.65)
## - 1 randf_range() call for elite teams (base_quality > 0.65) to determine tape_grinder bonus
##
## Parameters:
##   scout: Scout dictionary to modify (modified in-place)
##   quality: Quality metrics dictionary with keys: base_quality, noise_modifier, skill_modifier
##   rng: RNG instance for deterministic tape_grinder bonus generation
static func _apply_team_quality_to_scout(
	scout: Dictionary,
	quality: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	var skill_modifier := float(quality.get("skill_modifier", 1.0))
	var noise_modifier := float(quality.get("noise_modifier", 1.0))
	var base_quality := float(quality.get("base_quality", 0.50))

	# 1. Apply skill modifier to base_skill (better teams = more accurate)
	var base_skill := float(scout.get("base_skill", 0.55))
	scout["base_skill"] = clamp(base_skill * skill_modifier, 0.3, 0.9)

	# 2. Apply noise modifier to board_noise_sigma (better teams = less noise)
	var noise_sigma := float(scout.get("board_noise_sigma", 1.8))
	scout["board_noise_sigma"] = clamp(noise_sigma * noise_modifier, 0.8, 3.5)

	# 3. Elite teams (base_quality > 0.65) get tape_grinder bonus
	# This simulates better organizations emphasizing film study over combine numbers
	# RNG: Consumes 1 randf_range() call only for elite teams
	if base_quality > 0.65:
		var tape_grinder := float(scout.get("tape_grinder", 0.25))
		var tape_bonus := rng.randf_range(0.05, 0.15)
		scout["tape_grinder"] = clamp(tape_grinder + tape_bonus, 0.0, 1.0)


## Sorts teams by draft order, using previous season standings if available.
##
## For year > 0: Uses inverse standings (worst record picks first)
## For year 0: Falls back to static draft_order field
##
## Tiebreaker: strength_of_schedule (lower = earlier pick)
##
## RNG Pattern: None (pure deterministic sort)
func _sort_by_draft_order(teams: Array, world_state: Dictionary, year: int) -> Array:
	var sorted := teams.duplicate()

	# Try to use standings-based order from previous season
	if year > 0:
		var season_records: Dictionary = world_state.get("season_records", {})
		var prev_year_records: Dictionary = season_records.get(year - 1, {})

		if not prev_year_records.is_empty():
			# Sort by previous season performance (inverse standings)
			# Worst record → Pick 1st, Best record → Pick last
			sorted.sort_custom(func(a, b):
				var a_dict := a as Dictionary
				var b_dict := b as Dictionary
				var a_id := String(a_dict.get("id", ""))
				var b_id := String(b_dict.get("id", ""))

				var a_record: Dictionary = prev_year_records.get(a_id, {})
				var b_record: Dictionary = prev_year_records.get(b_id, {})

				var a_wins := int(a_record.get("wins", 0))
				var a_losses := int(a_record.get("losses", 0))
				var b_wins := int(b_record.get("wins", 0))
				var b_losses := int(b_record.get("losses", 0))

				# Calculate win percentage
				var a_games := a_wins + a_losses
				var b_games := b_wins + b_losses
				var a_win_pct := 0.0 if a_games == 0 else float(a_wins) / float(a_games)
				var b_win_pct := 0.0 if b_games == 0 else float(b_wins) / float(b_games)

				# Primary sort: lower win percentage picks earlier
				if abs(a_win_pct - b_win_pct) > 0.001:  # Avoid floating point comparison issues
					return a_win_pct < b_win_pct

				# Tiebreaker: strength of schedule (lower = earlier pick)
				var a_sos := float(a_record.get("strength_of_schedule", 0.5))
				var b_sos := float(b_record.get("strength_of_schedule", 0.5))
				return a_sos < b_sos
			)
			return sorted

	# Fallback: Use static draft_order field (for year 0 or if no records exist)
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
	score_cache: RecruitingScoreCache,
	year: int
) -> Array:
	var needs := _calculate_position_needs(roster, positions_cfg, class_rules)

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
	#
	# PHASE 5 ENHANCEMENTS:
	# - Deeper search in later rounds (round 4+: +20 players)
	# - Scout disagreement triggers expanded search
	# - Contrarian matches and measurement blind spots prioritized
	# - Rare elite slip mechanism (1.2% chance in rounds 4-5)
	var hidden_gem_count := 2 if round_num <= 4 else 3  # More deep dives in later rounds
	var gems_added := 0
	var search_start := max_candidates  # Start looking after the consensus top players

	# Get gem discovery configuration
	var gem_cfg: Dictionary = class_rules.get("draft_gem_discovery", {})
	var base_depth := int(gem_cfg.get("base_search_depth", 30))
	var search_depth := base_depth

	# Deeper search in later rounds (round 4+: +20 players)
	if round_num >= 4:
		search_depth = min(base_depth + 20, pool.size())

	# Calculate scout disagreement across prospects
	# High disagreement (>8.0 pts std dev) indicates hidden talent that scouts value differently
	# RNG: Consumes RNG for sampling 5 scouts with varied noise (deterministic via base_seed ^ 0xD15A6EE)
	var disagreement := _calculate_scout_disagreement(
		pool, scout, positions_cfg, stats_cfg, class_rules,
		search_start, min(search_start + search_depth, pool.size()), base_seed
	)

	# Expand search if high disagreement detected
	var disagreement_threshold := float(gem_cfg.get("disagreement_threshold", 8.0))
	if disagreement > disagreement_threshold:
		search_depth += 15
		hidden_gem_count += 1

	# Enhanced gem search loop with contrarian and measurement blind spot detection
	for i in range(search_start, min(search_start + search_depth, pool.size())):
		if gems_added >= hidden_gem_count:
			break
		var p: Dictionary = pool[i]
		var position := String(p.get("position", ""))

		# Detect contrarian matches (high mental stats when scout values mentals)
		var contrarian_match := _is_contrarian_match(p, scout, stats_cfg)

		# Detect measurement blind spots (elite ratings >78 in hard-to-measure stats ≤0.40 difficulty)
		var measurement_blind := _has_measurement_blind_spot(p, stats_cfg, gem_cfg)

		# Look for gems in positions with any need
		if position in positions_with_need and p not in candidates:
			# Prioritize contrarian matches and measurement blind spots at front of candidate pool
			if contrarian_match or measurement_blind:
				candidates.insert(0, p)
				gems_added += 1
			else:
				candidates.append(p)
				gems_added += 1

	# RARE ELITE SLIP MECHANISM: 1.2% chance per team pick in rounds 4-5
	# This simulates scenarios like George Kittle (#146) or Fred Warner (#154)
	# where elite talents slip due to measurement uncertainty or scheme fit biases
	#
	# RNG: Consumes 1 randf() call per round 4-5 pick (deterministic via base_seed ^ round_num ^ hash(team_id))
	if round_num >= 4 and round_num <= 5:
		var rare_chance := float(gem_cfg.get("rare_elite_slip_chance", 0.012))
		var slip_rng := RandomNumberGenerator.new()
		slip_rng.seed = Rand.splitmix64(base_seed ^ round_num ^ hash(team_id))

		# 1.2% chance to trigger elite slip search
		if slip_rng.randf() < rare_chance:
			# Search next 100 players for elite prospect (rating ≥ 78)
			for i in range(search_start, min(search_start + 100, pool.size())):
				var p: Dictionary = pool[i]
				var rating := PlayerRatingCalculator.calculate_overall_rating(
					p, positions_cfg, class_rules
				)
				# Insert at front of candidate pool if elite talent found
				if rating >= 78.0 and p not in candidates:
					var player_name := String(p.get("name", "Unknown"))
					var player_position := String(p.get("position", "?"))
					SimLogger.info("RARE EVENT: Elite slip - %s %s fell to round %d" % [
						player_position, player_name, round_num
					])
					candidates.insert(0, p)
					break

	# NOW run detailed scout evaluation on only these 12-16 candidates
	# Before: 100,000 evaluations per draft
	# After: 224 picks × 14 players = 3,136 evaluations per draft (97% reduction)
	var scored: Array = []
	var phase := "draft_round_%d" % round_num

	# Extract position_value multipliers from class_rules (legacy market value)
	var recruiting_cfg: Dictionary = class_rules.get("recruiting", {}) as Dictionary
	var position_values: Dictionary = recruiting_cfg.get("position_value", {}) as Dictionary

	# Extract draft_position_strategy (new tier-based system)
	var draft_strategy: Dictionary = class_rules.get("draft_position_strategy", {})

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

		# Calculate overall rating for position tier logic (generational check)
		var overall_rating := PlayerRatingCalculator.calculate_overall_rating(
			p, positions_cfg, class_rules
		)

		# Apply position tier multiplier based on round and position
		# This implements tier-based draft strategy (premium/standard/devalued positions)
		# and overrides legacy position_value for more realistic draft behavior
		var position_tier_mult := _get_position_tier_multiplier(
			position,
			round_num,
			overall_rating,
			draft_strategy
		)

		# Apply position value multiplier (legacy market value, still used for within-tier rankings)
		var position_value_mult := float(position_values.get(position, 1.0))

		# Apply position need weighting with round-based scaling
		# Early rounds (1-2): Need is minor factor (Best Player Available philosophy)
		# Later rounds (3+): Need becomes more important (fill roster gaps)
		var need_mult := float(needs.get(position, 1.0))
		var need_weight := 0.15 if round_num <= 2 else 0.30  # 15% weight in rounds 1-2, 30% in later rounds
		var need_adjustment := 1.0 + (need_mult - 1.0) * need_weight

		# Apply QB urgency boost for elite prospects (rating >= 75)
		# This ensures teams without franchise QBs aggressively target top QB prospects
		# Only boosts elite QBs to prevent reaching for mediocre prospects
		# NOTE: Uses FULL config multipliers (desperate: 2.8x, moderate: 1.6x) since
		# QB urgency is no longer applied in _calculate_position_needs()
		var qb_urgency_boost := 1.0
		if position == "QB" and overall_rating >= 75.0:
			var qb_urgency := _evaluate_qb_urgency(roster, positions_cfg, class_rules)
			var qb_cfg: Dictionary = class_rules.get("draft_qb_urgency", {})
			if qb_urgency.get("level") == "desperate":
				qb_urgency_boost = float(qb_cfg.get("desperate_multiplier", 2.8))
			elif qb_urgency.get("level") == "moderate":
				qb_urgency_boost = float(qb_cfg.get("moderate_multiplier", 1.6))

		# Calculate roster move net value
		# If drafting this player requires cutting someone, factor that into the evaluation
		var roster_move_penalty := _calculate_roster_move_penalty(
			roster,
			p,
			position,
			overall_rating
		)

		# Final weighted score: position tier is primary, position value is secondary, need is tertiary, QB urgency is final
		# Order: tier > market value > need > QB urgency > roster move net value
		# Roster move penalty reduces score if we'd have to cut a valuable player
		var weighted_score := base_score * position_tier_mult * position_value_mult * need_adjustment * qb_urgency_boost * roster_move_penalty

		scored.append({
			"player": p,
			"score": weighted_score,
			"base_score": base_score,
			"position_tier_mult": position_tier_mult,
			"position_value_mult": position_value_mult,
			"need_mult": need_mult,
			"overall_rating": overall_rating
		})

	# Sort by weighted score descending
	scored.sort_custom(func(a, b):
		return float((a as Dictionary).get("score", 0.0)) > float((b as Dictionary).get("score", 0.0))
	)

	# HARD FLOOR: Elite prospects (78+) cannot slip past round 3
	# Real NFL behavior: No QB rated 75+ has fallen past Round 2 in 20 years
	# No EDGE/CB rated 78+ has fallen past Round 3 in a decade
	#
	# This mechanism prevents elite prospects from falling to late rounds
	# if they weren't selected in earlier rounds (edge case failure mode).
	#
	# Implementation:
	# - Only activates in rounds 4+ (after Round 3 / pick 96)
	# - Rescues ONE elite prospect per pick (maintains variance)
	# - Excludes K/P (specialists have different draft dynamics)
	# - Inserts rescued prospect at TOP of scored list (highest priority)
	#
	# This complements the rare elite slip mechanism (rounds 4-5, 1.2% chance)
	# by providing a guaranteed floor for truly elite talent.
	#
	# RNG Note: This function is deterministic and does not consume RNG.
	# It performs rating calculations and list manipulation only.
	if round_num > 3:
		for player in pool:
			var p: Dictionary = player
			# Skip if already being evaluated
			if candidates.has(p):
				continue

			var rating := PlayerRatingCalculator.calculate_overall_rating(p, positions_cfg, class_rules)
			var position := String(p.get("position", ""))

			# Force elite non-specialists into evaluation after round 3
			# Priority insert ensures they're selected immediately
			if rating >= 78.0 and position not in ["K", "P"]:
				# Insert at top of scored list with artificially high score
				# This guarantees selection without disrupting normal scoring logic
				var rescue_entry := {
					"player": p,
					"score": ELITE_RESCUE_SCORE,
					"base_score": ELITE_RESCUE_SCORE,
					"position_tier_mult": 1.0,
					"position_value_mult": 1.0,
					"need_mult": 1.0,
					"overall_rating": rating
				}
				scored.insert(0, rescue_entry)
				break  # Only rescue one per pick to maintain variance

	return scored


## Gets position tier multiplier based on draft round and position.
##
## Premium positions (QB, EDGE, OL, CB) receive bonuses in early rounds.
## Devalued positions (RB, TE, S) receive penalties in early rounds unless generational talent.
## Special teams positions (K, P) are heavily penalized in all early rounds.
##
## RNG Note: This function is deterministic and does not consume RNG.
## It performs pure configuration lookups based on position and round.
##
## @param position: Player position (e.g., "QB", "RB", "OL")
## @param round: Current draft round (1-7)
## @param player_rating: Player's overall rating (for generational threshold check)
## @param draft_strategy: Configuration from class_rules["draft_position_strategy"]
## @return float: Multiplier to apply to draft score (0.3 to 1.4)
static func _get_position_tier_multiplier(
	position: String,
	round: int,
	player_rating: float,
	draft_strategy: Dictionary
) -> float:
	var generational_threshold := float(draft_strategy.get("generational_threshold", 78.0))

	# Generational talents (78+ rating) overcome position penalties
	# This allows elite RB/TE/S to go in round 1 despite position devaluation
	# EXCEPTION: K/P never get generational override (no kicker is worth a top pick)
	if player_rating >= generational_threshold and position not in ["K", "P"]:
		return 1.2  # 20% bonus for truly elite players

	var position_tiers: Dictionary = draft_strategy.get("position_tiers", {})

	# Find which tier this position belongs to
	for tier_name in position_tiers.keys():
		var tier: Dictionary = position_tiers[tier_name]
		var tier_positions: Array = tier.get("positions", [])

		if position in tier_positions:
			# Apply round-specific multiplier
			# Check both "bonus" and "penalty" keys for flexibility
			if round == 1:
				return float(tier.get("round_1_bonus", tier.get("round_1_penalty", 1.0)))
			elif round == 2:
				return float(tier.get("round_2_bonus", tier.get("round_2_penalty", 1.0)))
			elif round == 3:
				return float(tier.get("round_3_bonus", tier.get("round_3_penalty", 1.0)))
			else:
				return float(tier.get("round_4_plus_bonus", tier.get("round_4_plus_penalty", 1.0)))

	# Default: no modifier for unlisted positions
	return 1.0


## Calculates scout disagreement across a sample of prospects.
##
## Samples 5 scouts with varied noise levels and calculates standard deviation
## of their ratings for each player in the search range. High disagreement
## (>8.0 pts std dev) indicates hidden talent that scouts value differently.
##
## This simulates real NFL scouting where certain players are polarizing:
## - Hard-to-measure traits (coverage, football IQ, flexibility)
## - Scheme fit uncertainty
## - Projection vs production debates
##
## RNG: Consumes RNG for:
## - Creating 5 scout copies with noise variance (1 call per scout: randf_range)
## - Scoring each player with each scout (5 calls per player via ScoutRuntime.score_player)
##
## @param pool: Array of all draft-eligible players
## @param scout: Base team scout template
## @param positions_cfg: Position configuration
## @param stats_cfg: Stats configuration with measurement_difficulty
## @param class_rules: Class rules configuration
## @param start_idx: Start index in pool for disagreement calculation
## @param end_idx: End index in pool for disagreement calculation
## @param base_seed: Base RNG seed for determinism
## @return float: Average standard deviation of scout ratings (0.0-15.0 typical range)
static func _calculate_scout_disagreement(
	pool: Array,
	scout: Dictionary,
	positions_cfg: Dictionary,
	stats_cfg: Dictionary,
	class_rules: Dictionary,
	start_idx: int,
	end_idx: int,
	base_seed: int
) -> float:
	if end_idx - start_idx < 3:
		return 0.0

	# Sample 5 scouts with varied noise
	# This simulates multiple scouts evaluating the same players with different biases
	var sample_scouts: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = Rand.splitmix64(base_seed ^ 0xD15A6EE)

	# RNG: Consumes 5 randf_range() calls to create scout noise variance
	for i in range(5):
		var scout_copy: Dictionary = scout.duplicate(true)
		var noise_var := rng.randf_range(0.8, 1.4)
		scout_copy["board_noise_sigma"] = float(scout_copy.get("board_noise_sigma", 1.8)) * noise_var
		sample_scouts.append(scout_copy)

	var total_disagreement := 0.0
	var sample_count := 0

	# Calculate disagreement for each player in search range
	for i in range(start_idx, min(end_idx, pool.size())):
		var player: Dictionary = pool[i]
		var ratings: Array = []

		# Get rating from each scout
		# RNG: Consumes 5 ScoutRuntime.score_player() calls per player
		# Each score_player() call is deterministic via its own RNG seeded from base_seed ^ i ^ hash(scout)
		for s in sample_scouts:
			var eval_rng := RandomNumberGenerator.new()
			eval_rng.seed = Rand.splitmix64(base_seed ^ i ^ hash(s))
			var score := ScoutRuntime.score_player(
				s, player, positions_cfg, stats_cfg, class_rules, eval_rng
			)
			ratings.append(score)

		# Calculate standard deviation across scouts
		var mean := 0.0
		for r in ratings:
			mean += float(r)
		mean /= float(ratings.size())

		var variance := 0.0
		for r in ratings:
			var diff := float(r) - mean
			variance += diff * diff
		variance /= float(ratings.size())

		total_disagreement += sqrt(variance)
		sample_count += 1

	return total_disagreement / float(sample_count) if sample_count > 0 else 0.0


## Detects if a player is a contrarian match for this scout.
##
## A contrarian match occurs when:
## 1. Scout highly values mental stats (valuation_multiplier > 1.08)
## 2. Player has high mental stats (average > 72.0)
##
## This simulates "smart player" bias where scouts who value football IQ,
## decision-making, and coachability will find hidden gems that other scouts
## overlook due to lower physical measurables.
##
## Real NFL examples:
## - Fred Warner (LB): Elite football IQ, lower combine numbers
## - Russell Wilson (QB): Elite decision-making, height concerns
## - Zach Ertz (TE): High football IQ, slower 40-time
##
## RNG: This function is deterministic and does not consume RNG.
## It performs pure player/scout attribute comparisons.
##
## @param player: Player dictionary with stats
## @param scout: Scout dictionary with valuation_multipliers
## @param stats_cfg: Stats configuration (unused but kept for consistency)
## @return bool: True if player is a contrarian match
static func _is_contrarian_match(
	player: Dictionary,
	scout: Dictionary,
	stats_cfg: Dictionary
) -> bool:
	var val_mults: Dictionary = scout.get("valuation_multipliers", {})
	var mental_focus := false

	# Check if scout highly values any mental stats
	for stat in ["football_IQ", "decision_making", "coachability"]:
		if float(val_mults.get(stat, 1.0)) > 1.08:
			mental_focus = true
			break

	if not mental_focus:
		return false

	# Calculate player's mental stats average
	var stats: Dictionary = player.get("stats", {})
	var mental_avg := 0.0
	var mental_count := 0
	for stat in ["football_IQ", "decision_making", "coachability", "work_ethic"]:
		if stats.has(stat):
			mental_avg += float(stats.get(stat, 50.0))
			mental_count += 1

	if mental_count == 0:
		return false

	mental_avg /= float(mental_count)
	return mental_avg > 72.0


## Detects if a player has an elite rating in a hard-to-measure stat.
##
## Measurement blind spots occur when:
## 1. Stat has low measurement difficulty (≤0.40 threshold)
## 2. Player has elite rating in that stat (>78.0)
##
## Hard-to-measure stats (difficulty ≤0.40):
## - press_coverage (0.40) - INCLUDED
## - awareness (0.35)
## - discipline (0.40)
## - composure (0.30)
## - confidence (0.30)
## - aggression (0.40)
## - leadership (0.25)
## - loyalty (0.33)
## - work_ethic (0.30)
## - coachability (0.35)
## - decision_making (0.25)
## - anticipation (0.40)
## - football_IQ (0.30)
##
## This simulates how elite traits that are hard to quantify (flexibility,
## coverage ability, football IQ) can cause elite players to slip because
## scouts disagree on their true value.
##
## Real NFL examples:
## - George Kittle (TE): Elite flexibility (0.85 difficulty) → #146 overall
## - Richard Sherman (CB): Elite coverage instincts (0.45 difficulty) → #154
## - Tom Brady (QB): Elite decision-making (0.25 difficulty) → #199
##
## RNG: This function is deterministic and does not consume RNG.
## It performs pure stat lookups and comparisons.
##
## @param player: Player dictionary with stats
## @param stats_cfg: Stats configuration with measurement_difficulty
## @param gem_cfg: Gem discovery configuration with threshold
## @return bool: True if player has elite rating in hard-to-measure stat
static func _has_measurement_blind_spot(
	player: Dictionary,
	stats_cfg: Dictionary,
	gem_cfg: Dictionary
) -> bool:
	var uncertainty_threshold := float(gem_cfg.get("measurement_uncertainty_threshold", 0.40))

	var stats: Dictionary = player.get("stats", {})
	var stats_list: Array = stats_cfg.get("stats", [])

	# Check each stat for measurement blind spot
	for stat_def in stats_list:
		var sd: Dictionary = stat_def
		var stat_name := String(sd.get("name", ""))
		var difficulty := float(sd.get("measurement_difficulty", 0.5))

		# Hard-to-measure stat with elite rating = blind spot
		if difficulty <= uncertainty_threshold:
			var rating := float(stats.get(stat_name, 50.0))
			if rating > 78.0:
				return true

	return false


func _calculate_position_needs(
	roster: Dictionary,
	positions_cfg: Dictionary,
	class_rules: Dictionary = {}
) -> Dictionary:
	var by_position: Dictionary = roster.get("by_position", {}) as Dictionary
	var needs := {}

	for pos in positions_cfg.keys():
		var current_count := (by_position.get(pos, []) as Array).size()
		var ideal := RosterComposition.get_ideal_depth(pos)

		# More need = higher multiplier
		if current_count == 0:
			needs[pos] = 1.5  # High need
		elif current_count < ideal:
			var deficit := ideal - current_count
			needs[pos] = 1.0 + (float(deficit) / float(ideal)) * 0.3
		else:
			needs[pos] = 0.85  # Low need, slight penalty

	# NOTE: QB urgency is NOT applied here to avoid compound multipliers
	# QB urgency boost is applied separately in _score_draft_pool() for elite prospects (rating >= 75)
	# This ensures the config-specified multipliers (desperate: 2.8x, moderate: 1.6x) are applied exactly once

	return needs


## Returns top N alternative players from draft pool, excluding the specified player
## Used to show what other players were available when a pick was made
func _get_top_alternatives(pool: Array, count: int, exclude_id: String) -> Array:
	var sorted_pool: Array = pool.duplicate()
	sorted_pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("draft_score", 0.0)) > float(b.get("draft_score", 0.0))
	)

	var alternatives: Array = []
	for player in sorted_pool:
		var p: Dictionary = player
		if String(p.get("player_id", "")) != exclude_id:
			alternatives.append(p)
			if alternatives.size() >= count:
				break
	return alternatives


## Evaluates team's QB urgency level based on roster composition.
##
## Assesses franchise QB presence, age distribution, and succession planning
## to determine if team should aggressively target elite QB prospects.
##
## RNG Note: This function is deterministic and does not consume RNG.
## It performs pure roster analysis using PlayerRatingCalculator.
##
## Returns Dictionary with keys:
##   - level: "desperate" | "moderate" | "stable"
##   - multiplier: float (2.8 for desperate, 1.6 for moderate, 1.0 for stable)
##   - reason: string explanation of urgency level
static func _evaluate_qb_urgency(
	roster: Dictionary,
	positions_cfg: Dictionary,
	class_rules: Dictionary
) -> Dictionary:
	var qb_cfg: Dictionary = class_rules.get("draft_qb_urgency", {})
	if not bool(qb_cfg.get("enabled", true)):
		return {"level": "stable", "multiplier": 1.0}

	var by_position: Dictionary = roster.get("by_position", {})
	var all_players: Array = roster.get("players", [])
	var qb_ids: Array = by_position.get("QB", [])

	# No QB = desperate
	if qb_ids.is_empty():
		return {
			"level": "desperate",
			"multiplier": float(qb_cfg.get("desperate_multiplier", 2.8)),
			"reason": "no_qb"
		}

	# Extract QB objects
	var qbs: Array = []
	for player in all_players:
		var p: Dictionary = player
		var pid := String(p.get("player_id", ""))
		if pid in qb_ids:
			qbs.append(p)

	# Calculate best QB rating & age distribution
	var best_rating := 0.0
	var median_age := 0
	var has_young_qb := false
	var ages: Array = []

	for qb in qbs:
		var q: Dictionary = qb
		var rating := PlayerRatingCalculator.calculate_overall_rating(
			q, positions_cfg, class_rules
		)
		best_rating = max(best_rating, rating)
		var age := int(q.get("age", 25))
		ages.append(age)
		if age <= int(qb_cfg.get("succession_plan_age", 28)):
			has_young_qb = true

	ages.sort()
	median_age = ages[ages.size() / 2] if not ages.is_empty() else 25

	var franchise_threshold := float(qb_cfg.get("franchise_qb_threshold", 65.0))
	var aging_threshold := int(qb_cfg.get("aging_qb_age", 32))

	# Desperate: No franchise QB
	if best_rating < franchise_threshold:
		return {
			"level": "desperate",
			"multiplier": float(qb_cfg.get("desperate_multiplier", 2.8)),
			"reason": "no_franchise_qb"
		}

	# Moderate: Aging without succession
	if median_age > aging_threshold and not has_young_qb:
		return {
			"level": "moderate",
			"multiplier": float(qb_cfg.get("moderate_multiplier", 1.6)),
			"reason": "aging_no_succession"
		}

	return {"level": "stable", "multiplier": 1.0, "reason": "qb_room_set"}


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


## Calculate roster move penalty for draft evaluation
##
## When drafting a player to an overstocked position, calculate the penalty
## based on the value of the player who would need to be cut.
##
## Returns a multiplier (0.5-1.0):
##   - 1.0 = no cut needed (full value)
##   - 0.7 = cutting a decent backup (moderate penalty)
##   - 0.5 = cutting a valuable player (heavy penalty)
##
## This makes teams think about roster moves as packages:
## "Draft RB X + Cut RB#3 = net value of Y"
##
## TODO: Future enhancement - Complex multi-step roster moves
## Teams could plan contingent multi-action moves:
##   {draft: RB X, cut: RB#4, move: RB#3 to special teams} = net +12
##   {trade: CB#2 for pick, draft: CB Y, cut: CB#4} = net +8
## This would require a planning/optimization system to explore the solution space.
func _calculate_roster_move_penalty(
	roster: Dictionary,
	prospect: Dictionary,
	position: String,
	prospect_rating: float
) -> float:
	var by_position: Dictionary = roster.get("by_position", {}) as Dictionary
	var position_ids := by_position.get(position, []) as Array
	var ideal := RosterComposition.get_ideal_depth(position)

	# If not overstocked, no penalty (full value = 1.0)
	if position_ids.size() < ideal:
		return 1.0

	# Position is at or over ideal - find who would be cut
	var cut_player_rating := _find_cut_candidate_rating(roster, position)

	if cut_player_rating <= 0.0:
		return 1.0  # No one to cut, no penalty

	# Calculate penalty based on cut player value vs prospect value
	# If cutting someone nearly as good, heavy penalty
	# If cutting someone much weaker, light penalty
	var value_ratio := cut_player_rating / prospect_rating
	var penalty_factor := 0.5  # How much to penalize (50% max)

	# Apply penalty: score *= (1.0 - ratio * penalty_factor)
	# Examples:
	#   - Cut 65, draft 75 → ratio=0.867 → penalty=43% → multiplier=0.57
	#   - Cut 50, draft 75 → ratio=0.667 → penalty=33% → multiplier=0.67
	#   - Cut 75, draft 75 → ratio=1.0   → penalty=50% → multiplier=0.50 (don't do it!)
	var multiplier := 1.0 - (value_ratio * penalty_factor)

	# Clamp to reasonable range
	return clampf(multiplier, 0.3, 1.0)


## Find the rating of the player who would be cut at this position
##
## Returns the composite_score/overall rating of the weakest non-starter
## at the specified position, or 0.0 if no cut candidate exists.
func _find_cut_candidate_rating(
	roster: Dictionary,
	position: String
) -> float:
	var by_position: Dictionary = roster.get("by_position", {}) as Dictionary
	var position_ids := by_position.get(position, []) as Array

	if position_ids.size() <= 1:
		return 0.0  # Only have starter, can't cut

	var players: Array = roster.get("players", []) as Array
	var worst_rating := 9999.0

	# Find weakest player (skip index 0 = starter)
	for i in range(1, position_ids.size()):
		var pid := String(position_ids[i])
		for p in players:
			var player := p as Dictionary
			if String(player.get("player_id", "")) == pid:
				var rating := float(player.get("composite_score",
					player.get("overall", 50.0)))
				worst_rating = minf(worst_rating, rating)
				break

	return worst_rating if worst_rating < 9999.0 else 0.0


## Handle post-draft roster cuts when position is overstocked
##
## After drafting a player, if the position group exceeds ideal depth,
## release the weakest player at that position (excluding clear starter).
##
## This prevents roster composition issues like 5 RBs, 5 TEs when ideal is 4/3.
func _handle_post_draft_roster_cuts(
	world_state: Dictionary,
	roster: Dictionary,
	team_id: String,
	drafted_position: String,
	year: int,
	positions_cfg: Dictionary
) -> void:
	var by_position: Dictionary = roster.get("by_position", {}) as Dictionary
	var position_ids := by_position.get(drafted_position, []) as Array
	var ideal := RosterComposition.get_ideal_depth(drafted_position)

	# Only cut if we're overstocked (current > ideal)
	if position_ids.size() <= ideal:
		return

	# Find weakest player at this position (skip index 0 = starter)
	var worst_player_id: String = ""
	var worst_rating := 9999.0
	var players: Array = roster.get("players", []) as Array

	for i in range(1, position_ids.size()):  # Start at 1 to skip starter
		var pid := String(position_ids[i])
		for p in players:
			var player := p as Dictionary
			if String(player.get("player_id", "")) == pid:
				# Use composite_score or overall rating
				var rating := float(player.get("composite_score",
					player.get("overall", 50.0)))
				if rating < worst_rating:
					worst_rating = rating
					worst_player_id = pid
				break

	if worst_player_id.is_empty():
		return  # No suitable player to cut

	# Release player to undrafted pool
	var success := _release_player_to_undrafted_pool(
		world_state,
		roster,
		team_id,
		worst_player_id,
		year
	)

	if not success:
		SimLogger.warn("Post-draft roster cut failed for %s at position %s" % [
			team_id, drafted_position
		])


## Release a player from roster to undrafted pool
##
## Removes player from roster and adds them to the undrafted pool for the current year.
## This allows them to be signed during UDFA free agency phase.
##
## @return bool: True if player was found and released, false otherwise
func _release_player_to_undrafted_pool(
	world_state: Dictionary,
	roster: Dictionary,
	team_id: String,
	player_id: String,
	year: int
) -> bool:
	# Remove from roster players array
	var players: Array = roster.get("players", []) as Array
	var player_found := false

	for i in range(players.size() - 1, -1, -1):  # Loop backwards
		var p := players[i] as Dictionary
		if String(p.get("player_id", "")) == player_id:
			# Add to undrafted pool
			var undrafted_pool: Dictionary = world_state.get("undrafted_pool", {})
			if not undrafted_pool.has(year):
				undrafted_pool[year] = []

			# Clear contract/team info
			p["contract"] = {}
			p["team_id"] = ""

			(undrafted_pool[year] as Array).append(p)
			world_state["undrafted_pool"] = undrafted_pool

			# Remove from roster
			players.remove_at(i)

			# Log the cut
			SimLogger.info("Released %s (%s) from %s (roster cut after draft)" % [
				String(p.get("name", "Unknown")),
				String(p.get("position", "?")),
				team_id
			])
			player_found = true
			break

	if not player_found:
		SimLogger.error("Failed to release player %s from %s: player not found in roster" % [
			player_id, team_id
		])
		return false

	roster["players"] = players

	# Update by_position mapping
	var by_position: Dictionary = roster.get("by_position", {}) as Dictionary
	for pos in by_position.keys():
		var pos_ids := by_position[pos] as Array
		var updated_ids: Array = []
		for pid in pos_ids:
			if String(pid) != player_id:
				updated_ids.append(pid)
		by_position[pos] = updated_ids

	roster["by_position"] = by_position

	return true


func _create_rookie_contract(
	round_num: int,
	overall_pick: int,
	league_cfg: Dictionary,
	rng: RandomNumberGenerator,
	year: int
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

	# Calculate annual value (AAV) for cap tracking
	# Formula matches FreeAgency contract structure: base + amortized bonus
	var annual_value := base_salary + (signing_bonus / float(years))

	return {
		"type": "rookie",
		"years_total": years,
		"years_remaining": years,
		"base_salary": base_salary,
		"signing_bonus": signing_bonus,
		"annual_value": annual_value,
		"fifth_year_option": has_fifth_year_option,
		"gtd_remaining": signing_bonus,
		"signed_year": year
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


# ============================================================================
# FEATURE 5: DRAFT PICK TRADING
# ============================================================================

## Initializes draft pick ownership ledger for a draft year.
##
## Creates the ownership structure in world_state that tracks which team
## currently owns each draft pick. By default, each team owns their own picks.
## This ledger is updated when picks are traded.
##
## Data structure created:
##   world_state["draft_pick_ownership"][year][round][original_team_id] = current_owner_team_id
##
## Example:
##   ownership[2025][1]["SF"] = "CHI"  # Bears own 49ers' 1st round pick
##   ownership[2025][1]["CHI"] = "CHI" # Bears own their own pick
##
## RNG: None (deterministic initialization)
##
## @param world_state: World state dictionary to modify
## @param teams: Array of team dictionaries with "id" fields
## @param year: Draft year to initialize
## @param rounds: Number of draft rounds (typically 7)
static func initialize_pick_ownership(
	world_state: Dictionary,
	teams: Array,
	year: int,
	rounds: int
) -> void:
	if not world_state.has("draft_pick_ownership"):
		world_state["draft_pick_ownership"] = {}

	var ownership: Dictionary = world_state["draft_pick_ownership"]

	if not ownership.has(year):
		ownership[year] = {}

	var year_ownership: Dictionary = ownership[year]

	# Initialize each round
	for round_num in range(1, rounds + 1):
		if not year_ownership.has(round_num):
			year_ownership[round_num] = {}

		var round_ownership: Dictionary = year_ownership[round_num]

		# Each team owns their own pick by default
		for team in teams:
			var t: Dictionary = team
			var team_id := String(t.get("id", ""))
			if team_id != "":
				round_ownership[team_id] = team_id


## Resolves draft order for a specific round respecting pick ownership.
##
## Takes the base draft order (sorted by team performance) and applies
## pick ownership to determine who actually makes each selection.
##
## This is called at the start of each draft round to determine the
## correct picking order after accounting for trades.
##
## RNG: None (deterministic lookup)
##
## @param teams: Array of team dictionaries sorted by draft_order
## @param ownership: Draft pick ownership dictionary from world_state
## @param year: Draft year
## @param round_num: Current draft round (1-7)
## @return Array of pick assignments: [{pick_number, original_team_id, current_owner_id, traded}]
static func resolve_draft_order_with_ownership(
	teams: Array,
	ownership: Dictionary,
	year: int,
	round_num: int
) -> Array:
	var picks: Array = []

	# Get ownership for this year and round
	var year_ownership: Dictionary = ownership.get(year, {}) as Dictionary
	var round_ownership: Dictionary = year_ownership.get(round_num, {}) as Dictionary

	# Sort teams by draft order (worst to best)
	var sorted_teams := teams.duplicate()
	sorted_teams.sort_custom(func(a, b):
		return int((a as Dictionary).get("draft_order", 999)) < int((b as Dictionary).get("draft_order", 999))
	)

	var pick_number := 1
	for team in sorted_teams:
		var t: Dictionary = team
		var original_team_id := String(t.get("id", ""))

		# Check who owns this pick
		var current_owner_id := String(round_ownership.get(original_team_id, original_team_id))
		var is_traded := (current_owner_id != original_team_id)

		picks.append({
			"pick_number": pick_number,
			"original_team_id": original_team_id,
			"current_owner_id": current_owner_id,
			"traded": is_traded
		})

		pick_number += 1

	return picks


## Calculates trade value of a draft pick using pick value chart.
##
## Uses a Jimmy Johnson-style chart with values that decay as picks
## get later. Also applies a discount for future year picks to reflect
## the time value and uncertainty of future picks.
##
## Value chart approach:
##   - Round 1: 800-1000 points (elite value)
##   - Round 2: 450-600 points (high value)
##   - Round 3: 300-400 points (solid value)
##   - Round 4+: <250 points (depth value)
##
## Future pick discount:
##   - Current year: 1.0x (full value)
##   - Next year (+1): 0.9x (10% discount)
##   - Two years out (+2): 0.8x (20% discount)
##   - Three+ years out: 0.7x (30% discount)
##
## RNG: None (deterministic calculation)
##
## @param year: Draft year of the pick
## @param round_num: Round number (1-7)
## @param pick_in_round: Position within the round (1-32)
## @param current_year: Current simulation year (for future discount)
## @param config: Configuration dictionary with "draft_pick_trading" section
## @return float: Trade value points (0-1000 scale)
static func value_draft_pick(
	year: int,
	round_num: int,
	pick_in_round: int,
	current_year: int,
	config: Dictionary
) -> float:
	var trading_cfg: Dictionary = config.get("draft_pick_trading", {}) as Dictionary

	# Calculate overall pick number
	var overall_pick := (round_num - 1) * 32 + pick_in_round

	# Get base value from value chart
	# Using draft_picks.json structure via PickValueCurve logic
	var base_value := 0.0

	# Simple value curve based on round and position
	# Higher picks in earlier rounds are exponentially more valuable
	match round_num:
		1:
			# Round 1: 800-1000 points, declining within round
			base_value = 1000.0 - (float(pick_in_round - 1) / 31.0) * 200.0
		2:
			# Round 2: 450-600 points
			base_value = 600.0 - (float(pick_in_round - 1) / 31.0) * 150.0
		3:
			# Round 3: 300-400 points
			base_value = 400.0 - (float(pick_in_round - 1) / 31.0) * 100.0
		4:
			# Round 4: 175-250 points
			base_value = 250.0 - (float(pick_in_round - 1) / 31.0) * 75.0
		5:
			# Round 5: 100-150 points
			base_value = 150.0 - (float(pick_in_round - 1) / 31.0) * 50.0
		6:
			# Round 6: 60-90 points
			base_value = 90.0 - (float(pick_in_round - 1) / 31.0) * 30.0
		7:
			# Round 7: 30-50 points
			base_value = 50.0 - (float(pick_in_round - 1) / 31.0) * 20.0
		_:
			base_value = 10.0

	# Apply future year discount
	var years_in_future := year - current_year
	var future_discount := 1.0

	if years_in_future > 0:
		var discount_per_year := float(trading_cfg.get("future_year_discount", 0.9))
		# Compound discount: 0.9^years
		future_discount = pow(discount_per_year, float(years_in_future))
		# Floor at 0.7 (max 30% discount even for far future)
		future_discount = max(future_discount, 0.7)

	return base_value * future_discount


## Transfers ownership of a draft pick from one team to another.
##
## Updates the draft_pick_ownership ledger to reflect a trade.
## This is called when a trade involving picks is executed.
##
## RNG: None (deterministic update)
##
## @param world_state: World state dictionary to modify
## @param year: Draft year of the pick
## @param round_num: Round number (1-7)
## @param original_team_id: Team that originally owned the pick
## @param new_owner_id: Team that now owns the pick
static func transfer_pick_ownership(
	world_state: Dictionary,
	year: int,
	round_num: int,
	original_team_id: String,
	new_owner_id: String
) -> void:
	if not world_state.has("draft_pick_ownership"):
		world_state["draft_pick_ownership"] = {}

	var ownership: Dictionary = world_state["draft_pick_ownership"]

	if not ownership.has(year):
		ownership[year] = {}

	var year_ownership: Dictionary = ownership[year]

	if not year_ownership.has(round_num):
		year_ownership[round_num] = {}

	var round_ownership: Dictionary = year_ownership[round_num]

	# Update ownership
	round_ownership[original_team_id] = new_owner_id


# ============================================================================
# FEATURE 4: COMPENSATORY PICKS
# ============================================================================

## Tracks free agent transactions for compensatory pick calculation.
##
## This should be called at the end of free agency period to record all
## signings and losses for compensatory pick determination. The tracking
## data is stored in world_state["fa_transaction_tracking"].
##
## Data structure:
##   world_state["fa_transaction_tracking"][year][team_id] = {
##     "losses": [{player_id, value, destination_team}],
##     "gains": [{player_id, value, origin_team}]
##   }
##
## RNG: None (deterministic tracking)
##
## @param world_state: World state dictionary to modify
## @param year: Free agency year
## @param signings: Array of FA signings from FreeAgency.run_free_agency()
##                  Each signing: {player_id, team_id, contract, previous_team_id, player_value}
static func track_free_agent_transactions(
	world_state: Dictionary,
	year: int,
	signings: Array
) -> void:
	if not world_state.has("fa_transaction_tracking"):
		world_state["fa_transaction_tracking"] = {}

	var tracking: Dictionary = world_state["fa_transaction_tracking"]

	if not tracking.has(year):
		tracking[year] = {}

	var year_tracking: Dictionary = tracking[year]

	# Process each signing
	for signing in signings:
		var s: Dictionary = signing as Dictionary
		var player_id := String(s.get("player_id", ""))
		var new_team_id := String(s.get("team_id", ""))
		var previous_team_id := String(s.get("previous_team_id", ""))
		var player_value := float(s.get("player_value", 0.0))

		# Skip if no previous team (rookie FA)
		if previous_team_id == "" or previous_team_id == "UNDRAFTED":
			continue

		# Skip if player re-signed with same team
		if previous_team_id == new_team_id:
			continue

		# Initialize tracking for both teams if needed
		if not year_tracking.has(previous_team_id):
			year_tracking[previous_team_id] = {"losses": [], "gains": []}
		if not year_tracking.has(new_team_id):
			year_tracking[new_team_id] = {"losses": [], "gains": []}

		# Record loss for previous team
		var prev_team_data: Dictionary = year_tracking[previous_team_id]
		var losses: Array = prev_team_data.get("losses", []) as Array
		losses.append({
			"player_id": player_id,
			"value": player_value,
			"destination_team": new_team_id
		})
		prev_team_data["losses"] = losses

		# Record gain for new team
		var new_team_data: Dictionary = year_tracking[new_team_id]
		var gains: Array = new_team_data.get("gains", []) as Array
		gains.append({
			"player_id": player_id,
			"value": player_value,
			"origin_team": previous_team_id
		})
		new_team_data["gains"] = gains


## Calculates compensatory picks for teams based on FA net losses.
##
## Awards compensatory picks to teams that lost more/better free agents
## than they signed. Round assignment is based on the quality of players
## lost (elite = round 3, starter = round 4, depth = round 5).
##
## Algorithm:
##   1. For each team, calculate net FA loss value (losses - gains)
##   2. If net loss > threshold, team earns comp pick(s)
##   3. Round determined by departed player quality (80+ = Rd 3, 70-79 = Rd 4, 60-69 = Rd 5)
##   4. Teams can earn up to 4 comp picks maximum
##   5. Comp picks are ordered by net loss magnitude (higher loss = earlier pick)
##
## RNG: None (deterministic calculation)
##
## @param world_state: World state dictionary with fa_transaction_tracking
## @param year: Draft year to award picks for (typically FA year + 1)
## @param league_cfg: League configuration with compensatory_picks section
## @return Array of CompensatoryPick dictionaries
static func calculate_compensatory_picks(
	world_state: Dictionary,
	year: int,
	league_cfg: Dictionary
) -> Array:
	var comp_cfg: Dictionary = league_cfg.get("compensatory_picks", {}) as Dictionary

	# Check if comp picks are enabled
	if not bool(comp_cfg.get("enabled", true)):
		return []

	var tracking: Dictionary = world_state.get("fa_transaction_tracking", {}) as Dictionary
	var fa_year := year - 1  # Comp picks are for previous year's FA class
	var fa_tracking: Dictionary = tracking.get(fa_year, {}) as Dictionary

	if fa_tracking.is_empty():
		return []

	var net_loss_threshold := float(comp_cfg.get("net_loss_threshold", 50.0))
	var max_per_team := int(comp_cfg.get("max_per_team", 4))

	var comp_picks: Array = []

	# Calculate net losses for each team
	for team_id in fa_tracking.keys():
		var team_data: Dictionary = fa_tracking[team_id] as Dictionary
		var losses: Array = team_data.get("losses", []) as Array
		var gains: Array = team_data.get("gains", []) as Array

		# Calculate total loss value
		var total_loss_value := 0.0
		for loss in losses:
			var l: Dictionary = loss as Dictionary
			total_loss_value += float(l.get("value", 0.0))

		# Calculate total gain value
		var total_gain_value := 0.0
		for gain in gains:
			var g: Dictionary = gain as Dictionary
			total_gain_value += float(g.get("value", 0.0))

		# Calculate net loss
		var net_loss := total_loss_value - total_gain_value

		# Skip if net loss below threshold
		if net_loss < net_loss_threshold:
			continue

		# Award comp picks for each significant loss (up to max)
		var team_comp_picks: Array = []

		# Sort losses by value (highest first)
		var sorted_losses := losses.duplicate()
		sorted_losses.sort_custom(func(a, b):
			return float((a as Dictionary).get("value", 0.0)) > float((b as Dictionary).get("value", 0.0))
		)

		# Award picks for top losses
		for loss in sorted_losses:
			if team_comp_picks.size() >= max_per_team:
				break

			var l: Dictionary = loss as Dictionary
			var player_id := String(l.get("player_id", ""))
			var player_value := float(l.get("value", 0.0))

			# Determine comp pick round based on player quality
			var comp_round := _determine_comp_pick_round(player_value, comp_cfg)

			if comp_round > 0:
				team_comp_picks.append({
					"team_id": team_id,
					"year": year,
					"round": comp_round,
					"reason": "fa_loss_" + player_id,
					"player_lost_id": player_id,
					"player_lost_value": player_value,
					"net_loss": net_loss,
					"compensatory": true
				})

		comp_picks.append_array(team_comp_picks)

	# Sort comp picks by round, then by net loss (higher loss = earlier pick within round)
	comp_picks.sort_custom(func(a, b):
		var a_dict: Dictionary = a as Dictionary
		var b_dict: Dictionary = b as Dictionary
		var a_round := int(a_dict.get("round", 7))
		var b_round := int(b_dict.get("round", 7))
		if a_round != b_round:
			return a_round < b_round
		# Within same round, higher net loss picks earlier
		return float(a_dict.get("net_loss", 0.0)) > float(b_dict.get("net_loss", 0.0))
	)

	return comp_picks


## Determines compensatory pick round based on departed player value.
##
## Quality thresholds (using player overall rating as proxy for value):
##   - Elite (80+): Round 3
##   - Starter (70-79): Round 4
##   - Depth (60-69): Round 5
##   - Below depth: No comp pick
##
## RNG: None (deterministic lookup)
##
## @param player_value: Player market value (0-100 scale)
## @param comp_cfg: Compensatory picks configuration
## @return int: Round number (3-5) or 0 if no comp pick
static func _determine_comp_pick_round(
	player_value: float,
	comp_cfg: Dictionary
) -> int:
	var elite_round := int(comp_cfg.get("elite_comp_round", 3))
	var starter_round := int(comp_cfg.get("starter_comp_round", 4))
	var depth_round := int(comp_cfg.get("depth_comp_round", 5))

	# Value thresholds aligned with tier definitions
	if player_value >= 80.0:
		return elite_round
	elif player_value >= 70.0:
		return starter_round
	elif player_value >= 60.0:
		return depth_round
	else:
		return 0  # No comp pick for low-value losses


## Inserts compensatory picks into draft order at appropriate positions.
##
## Comp picks are added at the end of each round they're awarded in.
## This modifies the round_picks array to include comp picks in proper order.
##
## Also updates draft_pick_ownership to track comp pick ownership.
##
## RNG: None (deterministic insertion)
##
## @param round_picks: Array of pick assignments for a round
## @param comp_picks: Array of compensatory picks for this round
## @param year: Draft year
## @param round_num: Current round number
## @param world_state: World state (for updating ownership)
## @return Array: Modified round_picks with comp picks inserted
static func insert_compensatory_picks(
	round_picks: Array,
	comp_picks: Array,
	year: int,
	round_num: int,
	world_state: Dictionary
) -> Array:
	# Filter comp picks for this round
	var round_comp_picks: Array = []
	for cp in comp_picks:
		var pick: Dictionary = cp as Dictionary
		if int(pick.get("round", 0)) == round_num:
			round_comp_picks.append(pick)

	# If no comp picks for this round, return unchanged
	if round_comp_picks.is_empty():
		return round_picks

	# Create modified pick order with comp picks at end
	var modified_picks := round_picks.duplicate()

	# Get starting pick number for comp picks
	var next_pick_number := round_picks.size() + 1

	# Add comp picks
	for cp in round_comp_picks:
		var pick: Dictionary = cp as Dictionary
		var team_id := String(pick.get("team_id", ""))

		modified_picks.append({
			"pick_number": next_pick_number,
			"original_team_id": team_id,
			"current_owner_id": team_id,
			"traded": false,
			"compensatory": true,
			"reason": String(pick.get("reason", "")),
			"player_lost_value": float(pick.get("player_lost_value", 0.0))
		})

		# Update ownership ledger for comp pick
		# Comp picks are awarded to the team, so they own it by default
		if not world_state.has("draft_pick_ownership"):
			world_state["draft_pick_ownership"] = {}
		var ownership: Dictionary = world_state["draft_pick_ownership"]
		if not ownership.has(year):
			ownership[year] = {}
		var year_ownership: Dictionary = ownership[year]
		if not year_ownership.has(round_num):
			year_ownership[round_num] = {}
		var round_ownership: Dictionary = year_ownership[round_num]

		# Use team_id with comp suffix to avoid collision with regular picks
		var comp_pick_key := team_id + "_comp_" + str(next_pick_number)
		round_ownership[comp_pick_key] = team_id

		next_pick_number += 1

	return modified_picks

## Returns current timestamp in HH:MM:SS format
static func _get_timestamp() -> String:
	var time := Time.get_time_dict_from_system()
	return "%02d:%02d:%02d" % [time["hour"], time["minute"], time["second"]]
