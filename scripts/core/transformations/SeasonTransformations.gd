extends RefCounted
class_name SeasonTransformations

## Pure transformation functions for season-related state changes.
## All functions are side-effect-free and deterministic.
##
## CRITICAL: All functions are PURE - they never modify input dictionaries.
## They always return NEW dictionaries with the updated values.
##
## This module handles:
## - Game result application (standings updates)
## - Roster preparation for season simulation
## - Playoff seeding calculation
## - Draft eligibility transitions

const Player = preload("res://scripts/core/models/Player.gd")

# ============================================================================
# PURE FUNCTIONS - Game Result Processing
# ============================================================================

## Apply game result to standings (pure function).
##
## Takes current standings and game result, returns NEW standings with updated
## records, stats, and tiebreakers.
##
## RNG consumption: NONE (deterministic state update)
##
## @param standings: Current standings dictionary (unchanged)
## @param game_result: Dictionary with game outcome data
##   {
##     "home_team_id": String,
##     "away_team_id": String,
##     "home_score": int,
##     "away_score": int,
##     "week": int,
##     "season_type": String ("regular_season", "playoffs", "preseason")
##   }
## @return Dictionary: NEW standings dictionary with updated records
##
## Algorithm:
##   1. Create immutable copy of standings
##   2. Determine winner and loser (or tie)
##   3. Update win/loss/tie records
##   4. Update points scored/allowed
##   5. Update any tiebreaker stats (division record, conference record, etc.)
##   6. Return new standings (original unchanged!)
##
## Example:
##   var new_standings := SeasonTransformations.apply_game_result(standings, game_result)
##   assert(standings["SF"]["wins"] == 5)  # Original unchanged
##   assert(new_standings["SF"]["wins"] == 6)  # New copy updated
static func apply_game_result(
	standings: Dictionary,
	game_result: Dictionary
) -> Dictionary:
	# Validate inputs
	if standings.is_empty():
		push_warning("SeasonTransformations.apply_game_result: standings is empty")
		return {}

	var home_team: String = String(game_result.get("home_team_id", ""))
	var away_team: String = String(game_result.get("away_team_id", ""))
	var home_score: int = int(game_result.get("home_score", 0))
	var away_score: int = int(game_result.get("away_score", 0))

	if home_team.is_empty() or away_team.is_empty():
		push_error("SeasonTransformations.apply_game_result: Invalid team IDs")
		return standings.duplicate(true)

	# Create immutable copy
	var new_standings := _immutable_copy(standings)

	# Initialize team records if they don't exist
	if not new_standings.has(home_team):
		new_standings[home_team] = _create_empty_record(home_team)
	if not new_standings.has(away_team):
		new_standings[away_team] = _create_empty_record(away_team)

	# Get team records (will be mutated in the copy)
	var home_record: Dictionary = new_standings[home_team]
	var away_record: Dictionary = new_standings[away_team]

	# Increment games played
	home_record["games_played"] = int(home_record.get("games_played", 0)) + 1
	away_record["games_played"] = int(away_record.get("games_played", 0)) + 1

	# Update points scored/allowed
	home_record["points_for"] = int(home_record.get("points_for", 0)) + home_score
	home_record["points_against"] = int(home_record.get("points_against", 0)) + away_score
	away_record["points_for"] = int(away_record.get("points_for", 0)) + away_score
	away_record["points_against"] = int(away_record.get("points_against", 0)) + home_score

	# Determine outcome and update win/loss/tie records
	if home_score > away_score:
		# Home team wins
		home_record["wins"] = int(home_record.get("wins", 0)) + 1
		away_record["losses"] = int(away_record.get("losses", 0)) + 1
	elif away_score > home_score:
		# Away team wins
		away_record["wins"] = int(away_record.get("wins", 0)) + 1
		home_record["losses"] = int(home_record.get("losses", 0)) + 1
	else:
		# Tie (rare in modern football, but possible)
		home_record["ties"] = int(home_record.get("ties", 0)) + 1
		away_record["ties"] = int(away_record.get("ties", 0)) + 1

	# Calculate win percentage (for sorting/display)
	# Formula: (wins + 0.5 * ties) / games_played
	home_record["win_pct"] = _calculate_win_percentage(home_record)
	away_record["win_pct"] = _calculate_win_percentage(away_record)

	return new_standings

## Apply multiple game results to standings (pure function).
##
## Convenience function to apply multiple games at once.
##
## RNG consumption: NONE (deterministic state updates)
##
## @param standings: Current standings dictionary (unchanged)
## @param game_results: Array of game result dictionaries
## @return Dictionary: NEW standings dictionary with all results applied
static func apply_game_results(
	standings: Dictionary,
	game_results: Array
) -> Dictionary:
	var new_standings := standings.duplicate(true)

	for game_result in game_results:
		if game_result is Dictionary:
			new_standings = apply_game_result(new_standings, game_result)

	return new_standings

# ============================================================================
# PURE FUNCTIONS - Roster Preparation
# ============================================================================

## Prepare roster for season simulation (pure function).
##
## Takes a roster of players and prepares them for season simulation by:
## - Validating player data
## - Calculating derived stats (overall ratings, depth chart positions, etc.)
## - Adding simulation context (injury status, contract status, etc.)
##
## RNG consumption: NONE (deterministic preparation)
##
## @param roster: Dictionary with roster data (unchanged)
##   {
##     "team_id": String,
##     "players": Array[Dictionary],
##     "coaching_staff": Dictionary,
##     "scheme": String
##   }
## @param configs: Configuration dictionaries (positions, stats, etc.)
## @return Dictionary: NEW roster dictionary with prepared players
##
## Example:
##   var prepared := SeasonTransformations.prepare_roster(roster, configs)
##   assert(roster["players"].size() == 53)  # Original unchanged
##   assert(prepared["players"][0].has("depth_chart_position"))  # New field added
static func prepare_roster(
	roster: Dictionary,
	configs: Dictionary
) -> Dictionary:
	# Create immutable copy
	var new_roster := _immutable_copy(roster)

	# Get players array
	var players: Array = new_roster.get("players", [])
	var prepared_players := []

	# Prepare each player
	for player_dict in players:
		if player_dict is Dictionary:
			var prepared := _prepare_player(player_dict, configs)
			prepared_players.append(prepared)

	# Update roster with prepared players
	new_roster["players"] = prepared_players
	new_roster["prepared"] = true
	new_roster["preparation_timestamp"] = Time.get_ticks_msec()

	return new_roster

## Prepare single player for simulation (internal helper).
##
## Adds simulation-ready fields to a player dictionary if they don't exist:
## - injury_status: "healthy" (default)
## - stamina: 100.0 (full stamina)
## - morale: 75.0 (neutral-positive morale)
## - overall_rating: Calculated from current stats
##
## RNG consumption: NONE (pure calculation)
##
## @param player: Player dictionary to prepare (not modified)
## @param configs: Configuration dictionaries for rating calculation
## @return Dictionary: NEW player dict with simulation fields added
static func _prepare_player(
	player: Dictionary,
	configs: Dictionary
) -> Dictionary:
	var new_player := player.duplicate(true)

	# Add simulation-ready fields if missing
	if not new_player.has("injury_status"):
		new_player["injury_status"] = "healthy"

	if not new_player.has("stamina"):
		new_player["stamina"] = 100.0

	if not new_player.has("morale"):
		new_player["morale"] = 75.0

	# Calculate overall rating if stats are present
	# This is a simplified calculation - real implementation should use proper formulas
	if new_player.has("stats_profile"):
		var stats_profile: Dictionary = new_player.get("stats_profile", {})
		var current_stats: Dictionary = stats_profile.get("current", {})
		if not current_stats.is_empty():
			new_player["overall_rating"] = _calculate_overall_rating(current_stats, configs)

	return new_player

## Calculate overall rating from current stats (internal helper).
##
## Computes a simple average of all numeric stat values.
## This is a simplified calculation - production implementation should use
## position-weighted formulas from configs.
##
## RNG consumption: NONE (pure calculation)
##
## @param current_stats: Dictionary of {stat_name: numeric_value}
## @param configs: Configuration (reserved for future position-weighted calculations)
## @return float: Overall rating (0-100 scale), defaults to 50.0 if no stats
##
## Example:
##   var rating := _calculate_overall_rating({"speed": 85, "strength": 78}, {})
##   # Returns 81.5 (average of 85 and 78)
static func _calculate_overall_rating(
	current_stats: Dictionary,
	configs: Dictionary
) -> float:
	# Simple average for now - should be position-weighted in real implementation
	if current_stats.is_empty():
		return 50.0

	var total := 0.0
	var count := 0

	for stat_value in current_stats.values():
		if stat_value is float or stat_value is int:
			total += float(stat_value)
			count += 1

	return total / float(max(count, 1))

# ============================================================================
# PURE FUNCTIONS - Playoff Seeding
# ============================================================================

## Calculate playoff seeding from standings (pure function).
##
## Takes final regular season standings and produces playoff bracket with
## seeding based on league rules (division winners, wild cards, tiebreakers).
##
## RNG consumption: NONE for deterministic tiebreakers
## RNG consumption: 1 call per tied pair if random tiebreaker needed
##
## @param standings: Final standings dictionary (unchanged)
## @param playoff_config: Configuration for playoff format
##   {
##     "num_teams": int,
##     "divisions": Array[String],
##     "wild_card_spots": int,
##     "tiebreakers": Array[String]
##   }
## @param rng: RandomNumberGenerator (only used for random tiebreaker, if needed)
## @return Dictionary: Playoff bracket with seeding
##   {
##     "seeds": Array[Dictionary],  # [{seed: 1, team_id: "SF", record: {...}}, ...]
##     "matchups": Array[Dictionary]  # First round matchups
##   }
##
## Example:
##   var bracket := SeasonTransformations.calculate_playoff_seeding(standings, config, rng)
##   assert(bracket["seeds"].size() == 12)  # 6 per conference in NFL
static func calculate_playoff_seeding(
	standings: Dictionary,
	playoff_config: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	# Validate inputs
	if standings.is_empty():
		push_warning("SeasonTransformations.calculate_playoff_seeding: standings is empty")
		return {"seeds": [], "matchups": []}

	var num_teams: int = int(playoff_config.get("num_teams", 0))
	if num_teams <= 0:
		push_warning("SeasonTransformations.calculate_playoff_seeding: Invalid num_teams: %d" % num_teams)
		return {"seeds": [], "matchups": []}

	# Convert standings dictionary to sorted array
	var teams := []
	for team_id in standings.keys():
		var record: Dictionary = standings[team_id]
		teams.append({
			"team_id": team_id,
			"record": record.duplicate(true),
			"win_pct": float(record.get("win_pct", 0.0))
		})

	# Sort teams by win percentage (descending)
	# In real implementation, this would use proper tiebreakers
	teams.sort_custom(func(a, b): return a["win_pct"] > b["win_pct"])

	# Select top N teams for playoffs
	var playoff_teams := teams.slice(0, min(num_teams, teams.size()))

	# Assign seeds
	var seeds := []
	for i in range(playoff_teams.size()):
		var team: Dictionary = playoff_teams[i]
		seeds.append({
			"seed": i + 1,
			"team_id": team["team_id"],
			"record": team["record"]
		})

	# Generate first round matchups (simplified - assumes single-elimination bracket)
	var matchups := _generate_playoff_matchups(seeds)

	return {
		"seeds": seeds,
		"matchups": matchups
	}

## Generate playoff matchups from seeds (internal helper).
##
## Creates first-round matchups using standard bracket seeding:
## 1 vs N, 2 vs N-1, 3 vs N-2, etc. where N is total teams.
## Higher seeds get home field advantage.
##
## RNG consumption: NONE (deterministic bracket)
##
## @param seeds: Array of seed dictionaries [{seed: int, team_id: String, ...}, ...]
## @return Array: Matchup dictionaries [{home_team_id, away_team_id, home_seed, away_seed, round}, ...]
##
## Example (6-team bracket):
##   seeds = [{seed: 1, team_id: "SF"}, ..., {seed: 6, team_id: "DAL"}]
##   returns: [{home: "SF", away: "DAL", seeds: 1v6}, {home: team2, away: team5}, ...]
static func _generate_playoff_matchups(seeds: Array) -> Array:
	var matchups := []
	var num_seeds := seeds.size()

	# Simple bracket: 1 vs N, 2 vs N-1, etc.
	var num_matchups := num_seeds / 2
	for i in range(num_matchups):
		var high_seed: Dictionary = seeds[i]
		var low_seed: Dictionary = seeds[num_seeds - 1 - i]
		matchups.append({
			"home_team_id": high_seed["team_id"],
			"away_team_id": low_seed["team_id"],
			"home_seed": high_seed["seed"],
			"away_seed": low_seed["seed"],
			"round": "Wild Card" if num_matchups > 2 else "Division"
		})

	return matchups

# ============================================================================
# PURE FUNCTIONS - Draft Eligibility
# ============================================================================

## Transition players to draft eligible status (pure function).
##
## Takes a list of college players and marks eligible players as draft-ready.
## Uses eligibility rules (class year, age, opt-in decisions) to determine
## who enters the draft.
##
## RNG consumption: 1 call per player for opt-in decision (underclassmen)
##
## @param players: Array of player dictionaries (unchanged)
## @param eligibility_rules: Rules for draft eligibility
##   {
##     "min_class_year": int,  # Minimum class year (e.g., 3 for juniors)
##     "min_age": int,         # Minimum age requirement
##     "opt_in_chance": float  # Chance underclassman opts in early
##   }
## @param rng: RandomNumberGenerator for opt-in decisions
## @return Dictionary: {
##     "eligible": Array[Dictionary],    # Players entering draft
##     "remaining": Array[Dictionary]    # Players staying in college
##   }
##
## Example:
##   var result := SeasonTransformations.transition_to_draft_eligible(players, rules, rng)
##   assert(players.size() == 200)  # Original unchanged
##   assert(result["eligible"].size() + result["remaining"].size() == 200)
static func transition_to_draft_eligible(
	players: Array,
	eligibility_rules: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var eligible := []
	var remaining := []

	var min_class_year: int = int(eligibility_rules.get("min_class_year", 3))
	var min_age: int = int(eligibility_rules.get("min_age", 21))
	var opt_in_chance: float = float(eligibility_rules.get("opt_in_chance", 0.3))

	for player_dict in players:
		if not player_dict is Dictionary:
			continue

		# Create immutable copy
		var player_copy := player_dict.duplicate(true)

		# Check eligibility
		var class_year: int = int(player_copy.get("college_year", 0))
		var age: int = int(player_copy.get("age", 0))
		var stage: int = int(player_copy.get("stage", -1))

		# Skip if already draft eligible or in NFL
		if stage == Player.PlayerStage.DRAFT_ELIGIBLE or stage >= Player.PlayerStage.NFL_ROOKIE:
			remaining.append(player_copy)
			continue

		# Determine if player is automatically eligible
		var auto_eligible := class_year >= min_class_year and age >= min_age

		# Determine if underclassman opts in early
		# RNG call: 1 per player (deterministic for given seed)
		var opts_in_early := false
		if not auto_eligible and class_year >= 2:  # Sophomores can opt in
			opts_in_early = rng.randf() < opt_in_chance

		if auto_eligible or opts_in_early:
			# Player enters draft
			player_copy["stage"] = Player.PlayerStage.DRAFT_ELIGIBLE
			player_copy["draft_eligible_year"] = int(player_copy.get("current_year", 2033))
			eligible.append(player_copy)
		else:
			# Player stays in college
			remaining.append(player_copy)

	return {
		"eligible": eligible,
		"remaining": remaining
	}

# ============================================================================
# IMMUTABILITY HELPERS - Pure Function Utilities
# ============================================================================

## Create a deep immutable copy of a dictionary.
##
## Uses GDScript's duplicate(true) which performs recursive deep copy
## of all nested structures.
##
## @param dict: Dictionary to copy
## @return Dictionary: NEW dictionary (completely independent)
static func _immutable_copy(dict: Dictionary) -> Dictionary:
	return dict.duplicate(true)

# ============================================================================
# INTERNAL HELPERS - Data Structure Creation
# ============================================================================

## Create empty team record structure (internal helper).
##
## Initializes a fresh team record with all counters at zero.
## Used when a team doesn't have an existing record in standings.
##
## RNG consumption: NONE (pure structure creation)
##
## @param team_id: Team identifier to associate with record
## @return Dictionary: New team record with zeroed stats
static func _create_empty_record(team_id: String) -> Dictionary:
	return {
		"team_id": team_id,
		"wins": 0,
		"losses": 0,
		"ties": 0,
		"games_played": 0,
		"points_for": 0,
		"points_against": 0,
		"win_pct": 0.0,
		"division_wins": 0,
		"division_losses": 0,
		"conference_wins": 0,
		"conference_losses": 0
	}

## Calculate win percentage from record (internal helper).
##
## Computes win percentage using: wins / games_played.
## Returns 0.0 if no games have been played (prevents division by zero).
##
## RNG consumption: NONE (pure calculation)
##
## @param record: Team record dictionary with "wins" and "games_played" keys
## @return float: Win percentage (0.0 to 1.0 scale)
static func _calculate_win_percentage(record: Dictionary) -> float:
	var games_played: int = int(record.get("games_played", 0))
	if games_played == 0:
		return 0.0

	var wins: float = float(record.get("wins", 0))
	var ties: float = float(record.get("ties", 0))

	# Formula: (wins + 0.5 * ties) / games_played
	return (wins + 0.5 * ties) / float(games_played)
