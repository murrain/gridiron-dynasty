extends RefCounted
class_name PlayerMorale

## Player Morale and Satisfaction System
##
## Pure, stateless functions for calculating player satisfaction, morale, and transfer decisions.
## All functions are deterministic except transfer probability (which uses explicit RNG).
##
## Implements:
##   - PA6.1: Player Satisfaction from Playing Time and Awards
##   - PA6.2: Player Happiness/Morale System
##   - PA6.3: Transfer Decisions Based on Satisfaction
##
## Performance: O(n) where n = number of players
##
## Data Model:
##   player["satisfaction"] = 0-100 (calculated each season)
##   player["morale"] = 0-100 (multi-year cumulative trend)
##   world_state["transfer_portal"][year] = [player_dict, ...]
##
## Satisfaction Factors (target weights):
##   - Playing Time (40%): Starter status, games_started vs games_played
##   - Individual Awards (30%): OPOY/DPOY, All-Pro, Pro Bowl, Rookie awards
##   - Team Success (30%): Championships, playoffs, winning record
##
## Morale System:
##   - Range: 0-100, starts at 50 (neutral)
##   - Update formula: morale += (satisfaction - 50) * 0.3
##   - Affects development rate: dev_rate *= (morale / 50)
##
## Transfer Probability (college only):
##   - High morale (>70): 5% transfer chance
##   - Neutral morale (40-70): 15% transfer chance
##   - Low morale (<40): 40% transfer chance
##   - Seniors never transfer (graduating)

## Satisfaction score ranges for interpretation
const SATISFACTION_HIGH := 70.0
const SATISFACTION_NEUTRAL := 40.0
const SATISFACTION_LOW := 0.0

## Morale ranges for transfer probability
const MORALE_HIGH := 70.0
const MORALE_NEUTRAL := 40.0

## Transfer base probabilities
const TRANSFER_PROB_HIGH_MORALE := 0.05
const TRANSFER_PROB_NEUTRAL_MORALE := 0.15
const TRANSFER_PROB_LOW_MORALE := 0.40

## Satisfaction weight factors
const WEIGHT_PLAYING_TIME := 0.4
const WEIGHT_AWARDS := 0.3
const WEIGHT_TEAM_SUCCESS := 0.3

## Morale adjustment rate (how quickly satisfaction affects morale)
const MORALE_ADJUSTMENT_RATE := 0.3


## Calculates satisfaction score for a player based on playing time, awards, and team success.
##
## RNG Pattern: None (pure calculation, no randomness)
## Performance: O(1) per player
##
## Parameters:
##   player: Dictionary containing player data (player_id, position, etc.)
##   year: Current season year
##   player_stats: Dictionary - player_career_stats[player_id][year] (games_played, games_started)
##   awards: Dictionary - world_state["awards"][year] and world_state["all_pro_teams"][year], etc.
##   team_record: Dictionary - season_records[year][team_id] (wins, losses, playoff_appearance, champion)
##
## Returns:
##   float: Satisfaction score (0.0-100.0)
##
## Algorithm:
##   1. Calculate playing time score (0-100, weight 40%)
##   2. Calculate individual awards score (0-100, weight 30%)
##   3. Calculate team success score (0-100, weight 30%)
##   4. Weighted sum = satisfaction score
##
## Edge Cases:
##   - No stats for year: Returns 50.0 (neutral, player may be injured or redshirted)
##   - Missing team record: Returns 50.0 (neutral)
##   - Missing awards data: Awards score = 0
static func calculate_satisfaction(
	player: Dictionary,
	year: int,
	player_stats: Dictionary,
	awards: Dictionary,
	team_record: Dictionary
) -> float:
	var player_id := String(player.get("player_id", ""))
	if player_id.is_empty():
		return 50.0  # Neutral for invalid player

	# Fetch player's season stats
	var season_stats: Dictionary = player_stats.get(str(year), {})
	if season_stats.is_empty():
		# No stats for this year (injured, redshirted, or not on roster)
		return 50.0  # Neutral satisfaction

	# Calculate three components
	var playing_time_score := _calculate_playing_time_score(season_stats)
	var awards_score := _calculate_awards_score(player_id, year, awards)
	var team_success_score := _calculate_team_success_score(team_record)

	# Weighted sum
	var satisfaction := (
		playing_time_score * WEIGHT_PLAYING_TIME +
		awards_score * WEIGHT_AWARDS +
		team_success_score * WEIGHT_TEAM_SUCCESS
	)

	return clamp(satisfaction, 0.0, 100.0)


## Calculates playing time satisfaction score.
##
## Algorithm:
##   - Starter (games_started >= 8): +20 points (base 70)
##   - Regular backup (4-7 starts): +10 points (base 60)
##   - Rarely plays (< 4 starts): -10 points (base 40)
##   - Scale by games_played participation (full season = 12 college, 16 NFL)
##
## RNG Pattern: None (pure calculation)
##
## Parameters:
##   season_stats: Dictionary with games_played, games_started
##
## Returns:
##   float: Playing time score (0-100)
static func _calculate_playing_time_score(season_stats: Dictionary) -> float:
	var games_played := int(season_stats.get("games_played", 0))
	var games_started := int(season_stats.get("games_started", 0))

	# Base satisfaction: 50 (neutral)
	var score := 50.0

	# Playing time bonus/penalty
	if games_started >= 8:
		# Starter: +20 points
		score += 20.0
	elif games_started >= 4:
		# Regular backup: +10 points
		score += 10.0
	else:
		# Rarely plays: -10 points
		score -= 10.0

	# Participation bonus (scale by games played)
	# Full season (12 games college, 16 NFL) = +10 points
	# Half season (6 games) = +5 points
	var expected_season_length := 12.0  # College default
	if games_played >= 15:
		expected_season_length = 16.0  # NFL

	var participation_rate := float(games_played) / expected_season_length
	score += participation_rate * 10.0

	return clamp(score, 0.0, 100.0)


## Calculates individual awards satisfaction score.
##
## Award Values:
##   - OPOY/DPOY: +25 points
##   - All-Pro First Team: +20 points
##   - All-Pro Second Team: +15 points
##   - Pro Bowl: +10 points
##   - OROY/DROY: +15 points
##
## RNG Pattern: None (pure calculation)
##
## Parameters:
##   player_id: Player identifier
##   year: Season year
##   awards: Dictionary containing all award data
##
## Returns:
##   float: Awards score (0-100)
static func _calculate_awards_score(player_id: String, year: int, awards: Dictionary) -> float:
	var score := 0.0

	# Check year-specific awards
	var year_awards: Dictionary = awards.get("awards", {}).get(str(year), {})
	var all_pro_teams: Dictionary = awards.get("all_pro_teams", {}).get(str(year), {})
	var pro_bowl_rosters: Dictionary = awards.get("pro_bowl_rosters", {}).get(str(year), {})

	# Check OPOY/DPOY
	if year_awards.get("opoy", {}).get("player_id", "") == player_id:
		score += 25.0
	if year_awards.get("dpoy", {}).get("player_id", "") == player_id:
		score += 25.0

	# Check OROY/DROY
	if year_awards.get("oroy", {}).get("player_id", "") == player_id:
		score += 15.0
	if year_awards.get("droy", {}).get("player_id", "") == player_id:
		score += 15.0

	# Check All-Pro teams
	var first_team: Array = all_pro_teams.get("first_team", [])
	var second_team: Array = all_pro_teams.get("second_team", [])

	for player_data in first_team:
		var p: Dictionary = player_data
		if String(p.get("player_id", "")) == player_id:
			score += 20.0
			break

	for player_data in second_team:
		var p: Dictionary = player_data
		if String(p.get("player_id", "")) == player_id:
			score += 15.0
			break

	# Check Pro Bowl rosters
	var afc_roster: Array = pro_bowl_rosters.get("afc", [])
	var nfc_roster: Array = pro_bowl_rosters.get("nfc", [])

	for player_data in afc_roster:
		var p: Dictionary = player_data
		if String(p.get("player_id", "")) == player_id:
			score += 10.0
			break

	for player_data in nfc_roster:
		var p: Dictionary = player_data
		if String(p.get("player_id", "")) == player_id:
			score += 10.0
			break

	return clamp(score, 0.0, 100.0)


## Calculates team success satisfaction score.
##
## Success Factors:
##   - National Championship: +20 points
##   - Playoff appearance: +10 points
##   - Winning record (>8 wins): +5 points
##   - Losing record (<5 wins): -5 points
##
## RNG Pattern: None (pure calculation)
##
## Parameters:
##   team_record: Dictionary with wins, losses, playoff_appearance, is_champion flags
##
## Returns:
##   float: Team success score (0-100)
static func _calculate_team_success_score(team_record: Dictionary) -> float:
	var score := 50.0  # Base neutral

	var wins := int(team_record.get("wins", 0))
	var losses := int(team_record.get("losses", 0))
	var is_champion := bool(team_record.get("is_champion", false))
	var playoff_appearance := bool(team_record.get("playoff_appearance", false))

	# Championship: +20 points
	if is_champion:
		score += 20.0
	# Playoff appearance: +10 points (if not champion)
	elif playoff_appearance:
		score += 10.0

	# Winning record bonus/penalty
	if wins > 8:
		score += 5.0
	elif wins < 5:
		score -= 5.0

	return clamp(score, 0.0, 100.0)


## Updates player morale based on satisfaction trend.
##
## Morale is a cumulative, multi-year metric that trends with satisfaction.
## High satisfaction increases morale, low satisfaction decreases morale.
##
## Formula: morale += (satisfaction - 50) * MORALE_ADJUSTMENT_RATE
##
## RNG Pattern: None (pure calculation)
##
## Parameters:
##   player: Dictionary with current "morale" value (or initializes to 50)
##   satisfaction: Current year's satisfaction score (0-100)
##
## Returns:
##   float: Updated morale (0-100)
##
## Side Effects:
##   Modifies player["morale"] in-place
static func update_morale(player: Dictionary, satisfaction: float) -> float:
	# Initialize morale if not present
	var current_morale := float(player.get("morale", 50.0))

	# Adjust morale based on satisfaction deviation from neutral (50)
	var satisfaction_delta := satisfaction - 50.0
	var morale_change := satisfaction_delta * MORALE_ADJUSTMENT_RATE

	var new_morale := current_morale + morale_change
	new_morale = clamp(new_morale, 0.0, 100.0)

	# Update player dict
	player["morale"] = new_morale
	player["satisfaction"] = satisfaction

	return new_morale


## Calculates transfer probability for a college player based on morale.
##
## Transfer probabilities:
##   - High morale (>70): 5% transfer chance
##   - Neutral morale (40-70): 15% transfer chance
##   - Low morale (<40): 40% transfer chance
##   - Seniors: 0% (graduating, cannot transfer)
##
## RNG Pattern: None (this only calculates probability, not decision)
##
## Parameters:
##   player: Dictionary with morale and college_year
##
## Returns:
##   float: Transfer probability (0.0-1.0)
static func calculate_transfer_probability(player: Dictionary) -> float:
	# Seniors never transfer (graduating)
	var college_year := int(player.get("college_year", 1))
	if college_year >= 4:
		return 0.0

	var morale := float(player.get("morale", 50.0))

	if morale > MORALE_HIGH:
		return TRANSFER_PROB_HIGH_MORALE
	elif morale >= MORALE_NEUTRAL:
		return TRANSFER_PROB_NEUTRAL_MORALE
	else:
		return TRANSFER_PROB_LOW_MORALE


## Determines if a player enters the transfer portal (probabilistic).
##
## RNG Consumption: Exactly 1 randf() call per player
##
## Parameters:
##   player: Dictionary with morale and college_year
##   rng: RandomNumberGenerator (explicit, caller-controlled)
##
## Returns:
##   bool: True if player enters transfer portal
static func should_transfer(player: Dictionary, rng: RandomNumberGenerator) -> bool:
	var probability := calculate_transfer_probability(player)
	if probability <= 0.0:
		return false

	# RNG CALL: Exactly 1 randf() per player for transfer decision
	var roll := rng.randf()
	return roll < probability


## Calculates development rate multiplier based on morale.
##
## Formula: dev_rate_multiplier = morale / 50.0
##
## Examples:
##   - morale = 50: 1.0x development (neutral)
##   - morale = 75: 1.5x development (happy)
##   - morale = 25: 0.5x development (unhappy)
##
## RNG Pattern: None (pure calculation)
##
## Parameters:
##   morale: Player morale (0-100)
##
## Returns:
##   float: Development rate multiplier (typically 0.5-1.5)
static func calculate_development_multiplier(morale: float) -> float:
	return morale / 50.0


## Processes all players on a team to update satisfaction and morale.
##
## This is the main integration point for CollegeSeason.gd to update player morale.
##
## RNG Pattern: None (satisfaction/morale updates are deterministic)
##
## Parameters:
##   players: Array of player dictionaries
##   year: Current season year
##   player_career_stats: Dictionary - world_state["player_career_stats"]
##   awards: Dictionary - contains all award data from world_state
##   team_record: Dictionary - season_records[year][team_id]
##
## Returns:
##   Dictionary with summary: {players_updated, avg_satisfaction, avg_morale}
##
## Side Effects:
##   Modifies each player's "satisfaction" and "morale" fields in-place
static func update_team_morale(
	players: Array,
	year: int,
	player_career_stats: Dictionary,
	awards: Dictionary,
	team_record: Dictionary
) -> Dictionary:
	var players_updated := 0
	var total_satisfaction := 0.0
	var total_morale := 0.0

	for player in players:
		var p: Dictionary = player
		var player_id := String(p.get("player_id", ""))
		if player_id.is_empty():
			continue

		# Get player's specific stats for this year
		var player_stats: Dictionary = player_career_stats.get(player_id, {})

		# Calculate satisfaction
		var satisfaction := calculate_satisfaction(
			p,
			year,
			player_stats,
			awards,
			team_record
		)

		# Update morale
		var morale := update_morale(p, satisfaction)

		total_satisfaction += satisfaction
		total_morale += morale
		players_updated += 1

	return {
		"players_updated": players_updated,
		"avg_satisfaction": total_satisfaction / float(players_updated) if players_updated > 0 else 0.0,
		"avg_morale": total_morale / float(players_updated) if players_updated > 0 else 0.0
	}


## A4 Optimization: Batch morale updates with pre-fetched team context.
##
## Pre-fetches team-level data (stats, awards, team record) once per team instead of
## redundant lookups per player. This eliminates 156,000 dictionary traversals over
## 20 years (7,800 players × 20 years).
##
## RNG Pattern: None (satisfaction/morale updates are deterministic)
## Performance: O(players) with O(1) lookups instead of O(players × lookups)
##
## Parameters:
##   players: Array of player dictionaries for a single team
##   year: Current season year
##   team_batched_data: Dictionary with pre-fetched team context:
##     - "player_stats": Dictionary mapping player_id -> stats for this year
##     - "awards_lookup": Dictionary mapping player_id -> awards list
##     - "team_record": Dictionary with team success metrics
##
## Returns:
##   Dictionary with summary: {players_updated, avg_satisfaction, avg_morale}
##
## Side Effects:
##   Modifies each player's "satisfaction" and "morale" fields in-place
##
## Performance Impact:
##   - Before: 4 dictionary lookups per player (player_stats, awards, all_pro, pro_bowl)
##   - After: 1 dictionary lookup per player (pre-batched data)
##   - Expected savings: ~8 seconds over 20-year bootstrap
static func update_team_morale_batched(
	players: Array,
	year: int,
	team_batched_data: Dictionary
) -> Dictionary:
	var players_updated := 0
	var total_satisfaction := 0.0
	var total_morale := 0.0

	# Extract pre-batched team context
	var player_stats_lookup: Dictionary = team_batched_data.get("player_stats", {})
	var awards_lookup: Dictionary = team_batched_data.get("awards_lookup", {})
	var team_record: Dictionary = team_batched_data.get("team_record", {})

	for player in players:
		var p: Dictionary = player
		var player_id := String(p.get("player_id", ""))
		if player_id.is_empty():
			continue

		# Get player's specific stats for this year (single lookup)
		var player_stats: Dictionary = player_stats_lookup.get(player_id, {})

		# Get player's awards for this year (single lookup)
		var player_awards: Dictionary = awards_lookup.get(player_id, {})

		# Calculate satisfaction using batched data
		var satisfaction := _calculate_satisfaction_batched(
			p,
			year,
			player_stats,
			player_awards,
			team_record
		)

		# Update morale
		var morale := update_morale(p, satisfaction)

		total_satisfaction += satisfaction
		total_morale += morale
		players_updated += 1

	return {
		"players_updated": players_updated,
		"avg_satisfaction": total_satisfaction / float(players_updated) if players_updated > 0 else 0.0,
		"avg_morale": total_morale / float(players_updated) if players_updated > 0 else 0.0
	}


## Internal helper: Calculate satisfaction using pre-batched player awards.
##
## This is a streamlined version of calculate_satisfaction() that uses pre-fetched
## award data instead of traversing the full awards structure per player.
##
## RNG Pattern: None (pure calculation)
##
## Parameters:
##   player: Dictionary containing player data
##   year: Current season year
##   player_stats: Dictionary with player's season stats (already fetched)
##   player_awards: Dictionary with player's awards (already fetched)
##   team_record: Dictionary with team success metrics
##
## Returns:
##   float: Satisfaction score (0.0-100.0)
static func _calculate_satisfaction_batched(
	player: Dictionary,
	year: int,
	player_stats: Dictionary,
	player_awards: Dictionary,
	team_record: Dictionary
) -> float:
	if player_stats.is_empty():
		return 50.0  # Neutral satisfaction

	# Calculate three components
	var playing_time_score := _calculate_playing_time_score(player_stats)
	var awards_score := _calculate_awards_score_batched(player_awards)
	var team_success_score := _calculate_team_success_score(team_record)

	# Weighted sum
	var satisfaction := (
		playing_time_score * WEIGHT_PLAYING_TIME +
		awards_score * WEIGHT_AWARDS +
		team_success_score * WEIGHT_TEAM_SUCCESS
	)

	return clamp(satisfaction, 0.0, 100.0)


## Internal helper: Calculate awards score from pre-batched awards data.
##
## Optimized version that works with pre-fetched awards instead of traversing
## the full awards structure.
##
## RNG Pattern: None (pure calculation)
##
## Parameters:
##   player_awards: Dictionary with pre-fetched awards for this player:
##     - "opoy": bool
##     - "dpoy": bool
##     - "oroy": bool
##     - "droy": bool
##     - "all_pro_first": bool
##     - "all_pro_second": bool
##     - "pro_bowl": bool
##
## Returns:
##   float: Awards score (0-100)
static func _calculate_awards_score_batched(player_awards: Dictionary) -> float:
	var score := 0.0

	# Check OPOY/DPOY
	if player_awards.get("opoy", false):
		score += 25.0
	if player_awards.get("dpoy", false):
		score += 25.0

	# Check OROY/DROY
	if player_awards.get("oroy", false):
		score += 15.0
	if player_awards.get("droy", false):
		score += 15.0

	# Check All-Pro teams
	if player_awards.get("all_pro_first", false):
		score += 20.0
	elif player_awards.get("all_pro_second", false):
		score += 15.0

	# Check Pro Bowl
	if player_awards.get("pro_bowl", false):
		score += 10.0

	return clamp(score, 0.0, 100.0)


## A4 Optimization Helper: Pre-fetch and batch team data for morale updates.
##
## Builds a lookup structure for all players on a team, eliminating redundant
## dictionary traversals during morale calculation.
##
## RNG Pattern: None (pure data extraction)
## Performance: O(players) preprocessing, saves O(players × lookups) during updates
##
## Parameters:
##   players: Array of player dictionaries for a single team
##   year: Current season year
##   player_career_stats: Dictionary - world_state["player_career_stats"]
##   awards: Dictionary - contains all award data from world_state
##   team_record: Dictionary - season_records[year][team_id]
##
## Returns:
##   Dictionary with batched data ready for update_team_morale_batched():
##     - "player_stats": Dictionary mapping player_id -> season stats
##     - "awards_lookup": Dictionary mapping player_id -> awards flags
##     - "team_record": Dictionary with team success metrics
##
## Performance Impact:
##   - Pre-fetches all data once per team instead of per player
##   - Converts deep award structure traversal into shallow lookups
static func prepare_team_batched_data(
	players: Array,
	year: int,
	player_career_stats: Dictionary,
	awards: Dictionary,
	team_record: Dictionary
) -> Dictionary:
	var player_stats_lookup := {}
	var awards_lookup := {}

	# Extract year-specific awards data
	var year_awards: Dictionary = awards.get("awards", {}).get(str(year), {})
	var all_pro_teams: Dictionary = awards.get("all_pro_teams", {}).get(str(year), {})
	var pro_bowl_rosters: Dictionary = awards.get("pro_bowl_rosters", {}).get(str(year), {})

	# Build All-Pro player sets for fast lookup
	var all_pro_first_set := {}
	var all_pro_second_set := {}
	for player_data in all_pro_teams.get("first_team", []):
		var p: Dictionary = player_data
		all_pro_first_set[String(p.get("player_id", ""))] = true

	for player_data in all_pro_teams.get("second_team", []):
		var p: Dictionary = player_data
		all_pro_second_set[String(p.get("player_id", ""))] = true

	# Build Pro Bowl player set for fast lookup
	var pro_bowl_set := {}
	for player_data in pro_bowl_rosters.get("afc", []):
		var p: Dictionary = player_data
		pro_bowl_set[String(p.get("player_id", ""))] = true

	for player_data in pro_bowl_rosters.get("nfc", []):
		var p: Dictionary = player_data
		pro_bowl_set[String(p.get("player_id", ""))] = true

	# Extract award winners
	var opoy_id := String(year_awards.get("opoy", {}).get("player_id", ""))
	var dpoy_id := String(year_awards.get("dpoy", {}).get("player_id", ""))
	var oroy_id := String(year_awards.get("oroy", {}).get("player_id", ""))
	var droy_id := String(year_awards.get("droy", {}).get("player_id", ""))

	# Batch-process all players on team
	for player in players:
		var p: Dictionary = player
		var player_id := String(p.get("player_id", ""))
		if player_id.is_empty():
			continue

		# Fetch player stats for this year
		var player_year_stats: Dictionary = player_career_stats.get(player_id, {}).get(str(year), {})
		player_stats_lookup[player_id] = player_year_stats

		# Build awards flags for this player
		awards_lookup[player_id] = {
			"opoy": (player_id == opoy_id),
			"dpoy": (player_id == dpoy_id),
			"oroy": (player_id == oroy_id),
			"droy": (player_id == droy_id),
			"all_pro_first": all_pro_first_set.has(player_id),
			"all_pro_second": all_pro_second_set.has(player_id),
			"pro_bowl": pro_bowl_set.has(player_id)
		}

	return {
		"player_stats": player_stats_lookup,
		"awards_lookup": awards_lookup,
		"team_record": team_record
	}


## Processes transfer portal decisions for all players on a team.
##
## RNG Consumption: Exactly 1 randf() per eligible player (non-seniors)
##
## Parameters:
##   players: Array of player dictionaries (with morale values)
##   rng: RandomNumberGenerator (explicit, caller-controlled)
##
## Returns:
##   Array: List of players who entered the transfer portal
##
## Side Effects:
##   Does NOT modify player array - returns separate list of transfer players
static func determine_transfers(
	players: Array,
	rng: RandomNumberGenerator
) -> Array:
	var transfer_players := []

	for player in players:
		var p: Dictionary = player
		if should_transfer(p, rng):
			transfer_players.append(p)

	return transfer_players
