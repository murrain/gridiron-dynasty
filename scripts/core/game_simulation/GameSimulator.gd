extends RefCounted
class_name GameSimulator

## Game Simulation Engine
##
## Provides deterministic game simulation for college and NFL seasons.
## All functions are static and pure (except where explicit RNG is passed).
##
## Phase 1 Implementation:
## - Simple team strength calculation (mean roster rating)
## - Logistic win probability model with home field advantage
## - Deterministic winner determination
## - Round-robin college schedule generation
## - Division-based NFL schedule generation
## - Season result aggregation with strength of schedule
##
## RNG Pattern: All probabilistic functions accept RandomNumberGenerator as explicit parameter.
## Never creates new RNG instances internally - caller controls seeding for determinism.
##
## Performance Target: <5% overhead for full 20-year bootstrap
## Estimated: ~60µs per game, ~21,000 games = 1.26 seconds total

const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")
const StatGenerator = preload("res://scripts/core/game_simulation/StatGenerator.gd")

## Calculates team strength from roster composition.
##
## Phase 1 Algorithm: Mean of all player overall ratings.
## Future: Weighted by position importance, depth chart, injuries.
##
## RNG Consumption: None (pure calculation)
## Performance: O(n) where n = roster size (~50µs for 85 players)
##
## Parameters:
##   roster: Dictionary with "players" array
##   positions_cfg: Position config for rating calculation
##   main_cfg: Main config with class_rules
##
## Returns:
##   float: Team strength (0.0-100.0), default 50.0 for empty rosters
##
## Edge Cases:
##   - Empty roster: Returns 50.0 (neutral strength)
##   - Single player: Returns that player's rating
##   - All players rated 0: Returns 0.0
static func calculate_team_strength(
	roster: Dictionary,
	positions_cfg: Dictionary,
	main_cfg: Dictionary
) -> float:
	var players: Array = roster.get("players", [])

	# Edge case: Empty roster
	if players.is_empty():
		return 50.0  # Default to neutral strength

	var class_rules: Dictionary = main_cfg.get("class_rules", {})
	var total := 0.0
	var count := 0

	# Calculate overall rating for each player
	for player in players:
		var p: Dictionary = player
		var rating := PlayerRatingCalculator.calculate_overall_rating(
			p,
			positions_cfg,
			class_rules
		)
		total += rating
		count += 1

	# Return mean rating
	return total / float(count) if count > 0 else 50.0


## Calculates win probability using logistic function.
##
## Formula: P(win) = 1 / (1 + exp(-k * (strength_diff + home_advantage)))
##
## Where:
##   - k = strength_sensitivity (default 0.1)
##   - strength_diff = team_a_strength - team_b_strength
##   - home_advantage applied only if is_home = true
##
## RNG Consumption: None (pure math)
## Performance: O(1) (~5µs)
##
## Parameters:
##   team_a_strength: Team A strength (0.0-100.0)
##   team_b_strength: Team B strength (0.0-100.0)
##   is_home: Is team A playing at home?
##   cfg: Dictionary with "home_field_advantage" and "strength_sensitivity"
##
## Returns:
##   float: Probability team A wins (0.01-0.99, clamped to prevent certainty)
##
## Mathematical Properties:
##   - Symmetric: P(A beats B) = 1 - P(B beats A)
##   - Monotonic: Higher strength differential = higher win probability
##   - Bounded: Always in range (0.01, 0.99) - upsets always possible
##   - Home advantage: +3 strength ~ 58% win rate for equal teams
##
## Calibration Examples:
##   - diff=0, no home: 50% (even matchup)
##   - diff=0, home (+3): 58% (home advantage)
##   - diff=10: 73% (significant favorite)
##   - diff=20: 88% (strong favorite)
##   - diff=30: 95% (overwhelming favorite)
static func calculate_win_probability(
	team_a_strength: float,
	team_b_strength: float,
	is_home: bool,
	cfg: Dictionary
) -> float:
	var diff := team_a_strength - team_b_strength

	# Apply home field advantage (Phase 1: +3 points equivalent)
	# Expected RNG consumption: None (this is pure calculation)
	if is_home:
		var home_advantage := float(cfg.get("home_field_advantage", 3.0))
		diff += home_advantage

	# Logistic function: P(win) = 1 / (1 + e^(-k * diff))
	# k = 0.1 gives reasonable spread:
	#   diff=0  -> P=0.50 (50/50 game)
	#   diff=10 -> P=0.73 (73% favorite)
	#   diff=20 -> P=0.88 (88% favorite)
	#   diff=30 -> P=0.95 (95% favorite)
	var k := float(cfg.get("strength_sensitivity", 0.1))
	var exponent := -k * diff
	var probability := 1.0 / (1.0 + exp(exponent))

	# Clamp to prevent 100% certainty (upsets always possible)
	return clamp(probability, 0.01, 0.99)


## Determines winner for a single game using RNG roll against probability.
##
## RNG Consumption: Exactly 1 call (randf) - CRITICAL FOR DETERMINISM
## Performance: O(1) (~2µs)
##
## Algorithm:
##   1. Calculate home team win probability
##   2. Roll RNG (0.0-1.0)
##   3. Home wins if roll < probability
##   4. Detect upset if underdog by >upset_threshold won
##
## Parameters:
##   game_matchup: Dictionary with game info (GameMatchup structure)
##   team_strengths: Dictionary mapping team_id -> strength
##   rng: RandomNumberGenerator (explicit, caller-controlled)
##   cfg: Simulation config with thresholds
##
## Returns:
##   Dictionary: GameResult structure with winner, upset flag, probabilities
##
## Edge Cases:
##   - Missing team strengths: Default to 50.0
##   - Identical teams: 50/50 outcome (with home advantage applied)
##   - RNG roll exactly at threshold: Home wins (roll < prob)
static func determine_winner(
	game_matchup: Dictionary,
	team_strengths: Dictionary,
	rng: RandomNumberGenerator,
	cfg: Dictionary
) -> Dictionary:
	var home_id := String(game_matchup.get("home_team_id", ""))
	var away_id := String(game_matchup.get("away_team_id", ""))

	# Fetch team strengths (default to 50.0 if missing)
	var home_strength := float(team_strengths.get(home_id, 50.0))
	var away_strength := float(team_strengths.get(away_id, 50.0))

	# Calculate win probability for home team
	var home_win_prob := calculate_win_probability(
		home_strength,
		away_strength,
		true,  # is_home = true
		cfg
	)

	# RNG roll (CRITICAL: This is the ONLY RNG consumption in this function)
	# Expected: Exactly 1 randf() call per game for determinism
	var roll := rng.randf()  # 0.0-1.0

	# Determine winner
	var home_wins := (roll < home_win_prob)

	# Detect upsets (underdog by >upset_threshold wins)
	var upset := false
	var upset_threshold := float(cfg.get("upset_threshold", 5.0))
	if home_wins and away_strength > home_strength + upset_threshold:
		upset = true  # Away team was favored but lost
	elif not home_wins and home_strength > away_strength + upset_threshold:
		upset = true  # Home team was favored but lost

	# Construct result
	return {
		"game_id": String(game_matchup.get("game_id", "")),
		"year": int(game_matchup.get("year", 0)),
		"week": int(game_matchup.get("week", 0)),
		"home_team_id": home_id,
		"away_team_id": away_id,
		"winner_id": home_id if home_wins else away_id,
		"loser_id": away_id if home_wins else home_id,
		"home_score": 0,  # Phase 1: Not implemented
		"away_score": 0,  # Phase 1: Not implemented
		"game_type": String(game_matchup.get("game_type", "regular")),
		"is_overtime": false,  # Phase 1: Not implemented
		"upset": upset,
		"strength_differential": abs(home_strength - away_strength),
		"win_probability": home_win_prob if home_wins else (1.0 - home_win_prob)
	}


## Generates college regular season schedule using round-robin rotation.
##
## Phase 1 Algorithm: Simplified round-robin (no conference structure).
## All teams play each other in rotating fashion.
##
## RNG Consumption: N calls for shuffle (N = team count)
## Performance: O(weeks * teams) (~1ms for 130 teams * 12 weeks)
##
## Algorithm:
##   1. Extract team IDs from colleges array
##   2. Add "BYE" placeholder if odd number of teams
##   3. Shuffle teams using seed for deterministic randomness
##   4. Generate matchups using round-robin rotation:
##      - Team at index 0 stays fixed
##      - Others rotate clockwise each week
##      - Home/away alternates by week
##
## Parameters:
##   colleges: Array of college dictionaries with "id" field
##   year: Year for game_id generation
##   weeks: Number of weeks (typically 12)
##   seed: Seed for deterministic shuffling
##
## Returns:
##   Array[Dictionary]: Array of GameMatchup structures
##
## Properties:
##   - Coverage: Each team plays exactly 'weeks' games
##   - Balance: Home/away alternates each week
##   - Determinism: Same seed + colleges = same schedule
##
## Edge Cases:
##   - Odd number of teams: Adds "BYE" placeholder (filtered out)
##   - 0 weeks: Returns empty schedule
##   - 1 team: Cannot generate schedule (minimum 2 teams)
##
## Limitations (Phase 1):
##   - No conference structure
##   - No rivalry games
##   - No conference championship or bowl games
static func generate_college_schedule(
	colleges: Array,
	year: int,
	weeks: int,
	seed: int
) -> Array[Dictionary]:
	var schedule: Array[Dictionary] = []

	# Extract college IDs
	var team_ids: Array = []
	for college in colleges:
		var c: Dictionary = college
		team_ids.append(String(c.get("id", "")))

	# Ensure even number of teams (add bye if necessary)
	if team_ids.size() % 2 != 0:
		team_ids.append("BYE")  # Bye week placeholder

	# Shuffle teams for randomness (deterministic based on seed)
	# Expected RNG consumption: (N-1) randi_range() calls in Fisher-Yates shuffle
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	_shuffle_in_place(team_ids, rng)  # Deterministic shuffle using seeded RNG

	var num_teams := team_ids.size()
	var games_per_week := num_teams / 2

	# Round-robin rotation algorithm
	# Team at index 0 stays fixed, others rotate clockwise
	for week in range(1, weeks + 1):
		# Generate matchups for this week
		for game_idx in range(games_per_week):
			var home_idx := game_idx
			var away_idx := num_teams - 1 - game_idx

			var home_id: String = String(team_ids[home_idx])
			var away_id: String = String(team_ids[away_idx])

			# Skip bye games
			if home_id == "BYE" or away_id == "BYE":
				continue

			# Alternate home/away each week (home team has lower index in odd weeks)
			if week % 2 == 0:
				var temp: String = home_id
				home_id = away_id
				away_id = temp

			var game_id := "college_%d_w%d_g%d" % [year, week, game_idx]
			schedule.append({
				"game_id": game_id,
				"year": year,
				"week": week,
				"home_team_id": home_id,
				"away_team_id": away_id,
				"game_type": "regular"
			})

		# Rotate teams (keep index 0 fixed, rotate others)
		if week < weeks:
			var last = team_ids.pop_back()
			team_ids.insert(1, last)

	return schedule


## Generates simplified NFL schedule with division-based matchups.
##
## Phase 1 Algorithm: 6 intra-division games + 11 inter-division games (random rotation).
##
## RNG Consumption: N calls for shuffle operations (N = teams * weeks)
## Performance: O(teams^2) (~2ms for 32 teams)
##
## Algorithm:
##   1. Build division map (team_id -> division_id)
##   2. Phase 1: Intra-division games (weeks 1-6)
##      - Each team plays division opponents twice (home/away)
##   3. Phase 2: Inter-division games (weeks 7-17)
##      - Random rotation across divisions
##
## Parameters:
##   teams: Array of team dictionaries with "id" and "region" fields
##   divisions: Array of division dictionaries (currently unused in Phase 1)
##   year: Year for game_id generation
##   seed: Seed for deterministic rotation
##
## Returns:
##   Array[Dictionary]: Array of GameMatchup structures
##
## Properties:
##   - Division matchups: Each team plays division opponents 2x (home/away)
##   - Inter-division: Random rotation for remaining games
##   - Total games: 17 per team (6 divisional + 11 inter-divisional)
##   - Determinism: Same seed = same schedule
##
## Limitations (Phase 1):
##   - No realistic NFL schedule rotation (division vs division)
##   - No bye weeks
##   - No playoffs or Super Bowl
static func generate_nfl_schedule(
	teams: Array,
	divisions: Array,
	year: int,
	seed: int
) -> Array[Dictionary]:
	var schedule: Array[Dictionary] = []

	# Build division map (team_id -> division_id)
	var team_to_division := {}
	for team in teams:
		var t: Dictionary = team
		var team_id := String(t.get("id", ""))
		var region := String(t.get("region", ""))
		team_to_division[team_id] = region

	# Group teams by division
	var divisions_map := {}  # division_id -> [team_ids]
	for team in teams:
		var t: Dictionary = team
		var team_id := String(t.get("id", ""))
		var division_id := String(t.get("region", ""))
		if not divisions_map.has(division_id):
			divisions_map[division_id] = []
		(divisions_map[division_id] as Array).append(team_id)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var week := 1
	var game_counter := 0

	# Phase 1: Intra-division games (weeks 1-6)
	# Each team plays division opponents twice (home and away)
	# Expected RNG consumption: None for division games (deterministic pairing)
	for division_id in divisions_map.keys():
		var div_teams: Array = divisions_map[division_id]
		if div_teams.size() < 2:
			continue  # Skip invalid divisions

		# Round 1: Home games
		for i in range(div_teams.size()):
			for j in range(i + 1, div_teams.size()):
				var home_id := String(div_teams[i])
				var away_id := String(div_teams[j])

				var game_id := "nfl_%d_w%d_g%d" % [year, week, game_counter]
				schedule.append({
					"game_id": game_id,
					"year": year,
					"week": week,
					"home_team_id": home_id,
					"away_team_id": away_id,
					"game_type": "regular"
				})
				game_counter += 1

				# Advance week periodically (distribute games)
				if game_counter % 8 == 0:
					week += 1

		# Round 2: Away games (return matchups)
		for i in range(div_teams.size()):
			for j in range(i + 1, div_teams.size()):
				var home_id := String(div_teams[j])  # Reversed
				var away_id := String(div_teams[i])

				var game_id := "nfl_%d_w%d_g%d" % [year, week, game_counter]
				schedule.append({
					"game_id": game_id,
					"year": year,
					"week": week,
					"home_team_id": home_id,
					"away_team_id": away_id,
					"game_type": "regular"
				})
				game_counter += 1

				if game_counter % 8 == 0:
					week += 1

	# Phase 2: Inter-division games (weeks 7-17)
	# Simplified: Random matchups across divisions
	# Expected RNG consumption: (N-1) randi_range() calls per shuffle
	var all_teams := []
	for team in teams:
		var t: Dictionary = team
		all_teams.append(String(t.get("id", "")))

	_shuffle_in_place(all_teams, rng)  # Deterministic shuffle using seeded RNG

	while week <= 17:
		for i in range(0, all_teams.size(), 2):
			if i + 1 >= all_teams.size():
				break

			var home_id: String = String(all_teams[i])
			var away_id: String = String(all_teams[i + 1])

			var game_id := "nfl_%d_w%d_g%d" % [year, week, game_counter]
			schedule.append({
				"game_id": game_id,
				"year": year,
				"week": week,
				"home_team_id": home_id,
				"away_team_id": away_id,
				"game_type": "regular"
			})
			game_counter += 1

		week += 1
		_shuffle_in_place(all_teams, rng)  # Re-shuffle for next week (deterministic)

	return schedule


## Aggregates game results into per-team season records.
##
## Calculates:
##   - Wins/Losses per team
##   - Strength of schedule (mean opponent strength)
##
## RNG Consumption: None (pure aggregation)
## Performance: O(n) where n = number of games (~10µs for 1000 games)
##
## Algorithm:
##   1. Initialize season records for all teams
##   2. Accumulate W/L from game results
##   3. Calculate team strengths (win percentage as proxy)
##   4. Calculate strength of schedule (mean opponent strength)
##   5. Normalize SOS by number of games
##
## Parameters:
##   game_results: Array[Dictionary] (GameResult structures)
##   team_ids: Array of all team IDs in league
##
## Returns:
##   Dictionary: Mapping team_id -> SeasonRecord
##
## Edge Cases:
##   - Team with 0 games: W/L = 0, SOS = 0.0
##   - All teams undefeated: SOS based on circular logic (acceptable approximation)
static func aggregate_season_results(
	game_results: Array,
	team_ids: Array
) -> Dictionary:
	# Initialize season records for all teams
	var season_records := {}
	for team_id in team_ids:
		season_records[team_id] = {
			"team_id": team_id,
			"year": 0,  # Will be set from first game
			"wins": 0,
			"losses": 0,
			"conference_wins": 0,     # Phase 1: Not implemented
			"conference_losses": 0,   # Phase 1: Not implemented
			"strength_of_schedule": 0.0,  # Computed below
			"point_differential": 0,  # Phase 1: Not implemented
			"playoff_appearance": false,
			"bowl_game": "",
			"championship_winner": false,
			"super_bowl_winner": false
		}

	# Aggregate W/L from game results
	# Expected RNG consumption: None
	for result in game_results:
		var r: Dictionary = result
		var winner_id := String(r.get("winner_id", ""))
		var loser_id := String(r.get("loser_id", ""))
		var year := int(r.get("year", 0))

		if season_records.has(winner_id):
			var winner_record: Dictionary = season_records[winner_id]
			winner_record["wins"] = int(winner_record.get("wins", 0)) + 1
			winner_record["year"] = year

		if season_records.has(loser_id):
			var loser_record: Dictionary = season_records[loser_id]
			loser_record["losses"] = int(loser_record.get("losses", 0)) + 1
			loser_record["year"] = year

	# Compute strength of schedule (mean opponent strength)
	# For Phase 1: Use win percentage as proxy for strength
	var team_strengths := {}
	for team_id in season_records.keys():
		var record: Dictionary = season_records[team_id]
		var total_games := int(record["wins"]) + int(record["losses"])
		var win_pct := float(record["wins"]) / float(max(1, total_games))
		team_strengths[team_id] = win_pct * 100.0

	# Calculate SOS for each team (accumulate opponent strengths)
	for result in game_results:
		var r: Dictionary = result
		var home_id := String(r.get("home_team_id", ""))
		var away_id := String(r.get("away_team_id", ""))

		# Add opponent strength to SOS accumulator
		if season_records.has(home_id):
			var home_record: Dictionary = season_records[home_id]
			var opp_strength := float(team_strengths.get(away_id, 50.0))
			home_record["strength_of_schedule"] = float(home_record.get("strength_of_schedule", 0.0)) + opp_strength

		if season_records.has(away_id):
			var away_record: Dictionary = season_records[away_id]
			var opp_strength := float(team_strengths.get(home_id, 50.0))
			away_record["strength_of_schedule"] = float(away_record.get("strength_of_schedule", 0.0)) + opp_strength

	# Normalize SOS (divide by number of games)
	for team_id in season_records.keys():
		var record: Dictionary = season_records[team_id]
		var total_games := int(record["wins"]) + int(record["losses"])
		if total_games > 0:
			record["strength_of_schedule"] = float(record.get("strength_of_schedule", 0.0)) / float(total_games)

	return season_records


## Accumulates player stats for a single game into world_state.
##
## Updates world_state["player_career_stats"][player_id][year] with cumulative stats.
## If stats don't exist for a player/year, creates new entry.
## If stats exist, adds new stats to existing stats.
##
## RNG Consumption: Variable (see StatGenerator.generate_game_stats documentation)
## Performance: O(n) where n = total players in game (~50-100 players)
##
## Algorithm:
##   1. Generate stats for all players in both teams
##   2. For each player, accumulate stats into world_state
##   3. Handle first-time player/year combinations
##   4. Add stats to existing totals
##
## Parameters:
##   world_state: Dictionary containing player_career_stats
##   game_result: GameResult dictionary from determine_winner
##   home_roster: Dictionary with "players" array
##   away_roster: Dictionary with "players" array
##   positions_cfg: Position configuration
##   main_cfg: Main configuration
##   rng: RandomNumberGenerator (explicit, caller-controlled)
##
## Side Effects:
##   - Modifies world_state["player_career_stats"] in-place
##
## Edge Cases:
##   - First game for player: Creates new year entry
##   - Player changes teams mid-season: Updates team_id (latest team wins)
##   - Missing player_career_stats structure: Creates it
static func accumulate_player_stats(
	world_state: Dictionary,
	game_result: Dictionary,
	home_roster: Dictionary,
	away_roster: Dictionary,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	# Ensure player_career_stats structure exists
	if not world_state.has("player_career_stats"):
		world_state["player_career_stats"] = {}

	var career_stats: Dictionary = world_state["player_career_stats"]

	# Generate stats for all players in this game
	# Expected RNG consumption: Variable per player (see StatGenerator documentation)
	var game_stats := StatGenerator.generate_game_stats(
		home_roster,
		away_roster,
		game_result,
		positions_cfg,
		main_cfg,
		rng
	)

	# Accumulate stats into career totals
	# Expected RNG consumption: None (pure aggregation)
	for player_id in game_stats.keys():
		var stat_line: Dictionary = game_stats[player_id]
		var year := int(stat_line.get("year", 0))

		# Initialize player career stats if needed
		if not career_stats.has(player_id):
			career_stats[player_id] = {}

		var player_years: Dictionary = career_stats[player_id]

		# Initialize year stats if needed
		if not player_years.has(year):
			player_years[year] = stat_line.duplicate()
		else:
			# Accumulate stats into existing year totals
			var existing: Dictionary = player_years[year]
			_accumulate_stat_line(existing, stat_line)

	world_state["player_career_stats"] = career_stats


## Accumulates a stat line into an existing stat line.
##
## RNG Consumption: None (pure aggregation)
##
## Algorithm:
##   1. For each numeric field in new_stats
##   2. Add value to existing[field]
##   3. Skip non-numeric fields (year, team_id, position)
##   4. Update team_id and position to latest values
##
## Parameters:
##   existing: Dictionary to accumulate into (modified in-place)
##   new_stats: Dictionary with new stats to add
##
## Side Effects:
##   - Modifies existing in-place
##
## Special Handling:
##   - "year", "position": Keep existing value (don't accumulate)
##   - "team_id": Update to latest value (player may have changed teams)
##   - All numeric fields: Accumulate (add new to existing)
static func _accumulate_stat_line(existing: Dictionary, new_stats: Dictionary) -> void:
	# Update team_id to latest (player may have changed teams)
	if new_stats.has("team_id"):
		existing["team_id"] = new_stats["team_id"]

	# Accumulate all numeric fields
	for key in new_stats.keys():
		# Skip non-accumulating fields
		if key in ["year", "position", "team_id"]:
			continue

		# Add numeric values
		var new_value = new_stats.get(key, 0)
		if typeof(new_value) == TYPE_INT or typeof(new_value) == TYPE_FLOAT:
			var existing_value = existing.get(key, 0)
			existing[key] = int(existing_value) + int(new_value)


## Deterministic Fisher-Yates shuffle using seeded RNG.
##
## Shuffles an array in-place using the provided RandomNumberGenerator.
## This ensures deterministic behavior across different executions with the same seed.
##
## RNG Pattern: Exactly (items.size() - 1) randi_range() calls
##
## @param items: Array to shuffle in-place (will be modified)
## @param rng: RandomNumberGenerator instance (must be seeded by caller)
static func _shuffle_in_place(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp
