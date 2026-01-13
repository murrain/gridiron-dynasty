extends RefCounted
class_name CollegeAwardsService

## College Awards Selection Service
##
## Pure functional service for selecting college football awards and generating
## mock draft rankings with media hype influence.
##
## Implements Phase 6: College Awards & Media Hype
##   - Heisman Trophy (winner + finalists)
##   - All-American Teams (1st, 2nd, 3rd)
##   - Conference Awards (Offensive/Defensive POY)
##   - Mock Draft Rankings (ESPN, NFL Network, PFF)
##
## All functions are static and pure (no state mutation).
## Award selections are deterministic (no RNG).
## Mock draft generation uses RNG for intentional noise/bias.
##
## Performance: O(n log n) where n = number of draft-eligible players (~500)
##
## Data Model:
##   Reads from: world_state["player_career_stats"], world_state["season_records"]
##   Writes to: world_state["college_awards"], world_state["all_american_teams"], world_state["mock_drafts"]

const CollegeStatsService = preload("res://scripts/world/CollegeStatsService.gd")
const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")

## Position groups for award eligibility
const HEISMAN_POSITIONS := ["QB", "RB", "WR"]
const OFFENSIVE_POSITIONS := ["QB", "RB", "WR", "TE", "OL", "OT", "OG", "C"]
const DEFENSIVE_POSITIONS := ["DL", "DT", "DE", "EDGE", "LB", "CB", "S"]


## Selects all college awards for a given season.
##
## This is the main entry point that orchestrates all award selections.
## Follows the pattern of AwardSelector.select_all_awards() for consistency.
##
## Parameters:
##   world_state: Dictionary containing player_career_stats, season_records, colleges
##   year: Season year for award selection
##   config: Dictionary from college_awards.json configuration
##
## Returns:
##   Dictionary with summary of all awards selected
##
## Side Effects:
##   Modifies world_state to add award results to:
##     - world_state["college_awards"][year]
##     - world_state["all_american_teams"][year]
##
## RNG Pattern: None (deterministic award selection)
## Performance: O(n log n) where n = draft-eligible players
static func select_all_college_awards(
	world_state: Dictionary,
	year: int,
	config: Dictionary
) -> Dictionary:
	var career_stats: Dictionary = world_state.get("player_career_stats", {})
	var season_records: Dictionary = world_state.get("season_records", {}).get(year, {})
	var colleges: Array = world_state.get("colleges", [])

	if career_stats.is_empty():
		return {
			"error": "No player stats available for award selection",
			"year": year
		}

	# Build college index for team success lookups
	var college_index := _build_college_index(colleges)

	# Extract draft-eligible players with season stats
	var draft_pool: Dictionary = world_state.get("draft_pool", {})
	var eligible_players: Array = draft_pool.get(year, [])

	if eligible_players.is_empty():
		return {
			"warning": "No draft-eligible players for year %d" % year,
			"year": year
		}

	# Select Heisman Trophy (winner + finalists)
	var heisman := select_heisman_trophy(
		eligible_players,
		career_stats,
		season_records,
		college_index,
		year,
		config
	)

	# Select All-American Teams
	var all_americans := select_all_americans(
		eligible_players,
		career_stats,
		year,
		config
	)

	# Select Conference Awards
	var conference_awards := select_conference_awards(
		eligible_players,
		career_stats,
		season_records,
		college_index,
		year,
		config
	)

	# Store in world_state
	var college_awards: Dictionary = world_state.get("college_awards", {})
	if not college_awards.has(year):
		college_awards[year] = {}

	college_awards[year] = {
		"heisman": heisman,
		"conference_awards": conference_awards
	}
	world_state["college_awards"] = college_awards

	var all_american_teams: Dictionary = world_state.get("all_american_teams", {})
	all_american_teams[year] = all_americans
	world_state["all_american_teams"] = all_american_teams

	# Update player award references
	_update_player_award_references(
		world_state,
		year,
		heisman,
		all_americans,
		conference_awards
	)

	return {
		"year": year,
		"heisman_winner": heisman.get("winner", {}).get("player_id", ""),
		"heisman_finalists": heisman.get("finalists", []).size(),
		"all_american_first_team": all_americans.get("first_team", []).size(),
		"all_american_second_team": all_americans.get("second_team", []).size(),
		"all_american_third_team": all_americans.get("third_team", []).size(),
		"conference_awards_count": conference_awards.size()
	}


## Selects Heisman Trophy winner and finalists.
##
## Algorithm:
##   1. Filter to Heisman-eligible positions (QB, RB, WR)
##   2. Calculate composite score based on:
##      - Statistical production (40%)
##      - Efficiency metrics (25%)
##      - Team success (20%)
##      - Media hype (15%)
##   3. Sort by score and select top 4 finalists
##   4. Highest scorer wins
##
## Parameters:
##   eligible_players: Array of draft-eligible players
##   career_stats: Dictionary of player career stats
##   season_records: Dictionary of team W-L records
##   college_index: Dictionary mapping college_id -> college data
##   year: Season year
##   config: Dictionary from college_awards.json
##
## Returns:
##   Dictionary with winner and finalists
##
## RNG Pattern: None (deterministic)
static func select_heisman_trophy(
	eligible_players: Array,
	career_stats: Dictionary,
	season_records: Dictionary,
	college_index: Dictionary,
	year: int,
	config: Dictionary
) -> Dictionary:
	var heisman_cfg: Dictionary = config.get("heisman", {})
	var eligible_positions: Array = heisman_cfg.get("eligible_positions", HEISMAN_POSITIONS)
	var finalist_count := int(heisman_cfg.get("finalist_count", 4))
	var min_games := int(heisman_cfg.get("min_games_played", 10))

	# Filter to Heisman-eligible positions
	var candidates := []
	for player in eligible_players:
		var p: Dictionary = player
		var player_id := String(p.get("player_id", ""))
		var position := String(p.get("position", ""))
		var school_id := String(p.get("college_id", ""))

		if position not in HEISMAN_POSITIONS:
			continue

		# Get season stats
		var player_stats: Dictionary = career_stats.get(player_id, {})
		var season_stats: Dictionary = player_stats.get(year, {})

		if season_stats.is_empty():
			continue

		var games_played := int(season_stats.get("games_played", 0))

		if games_played < min_games:
			continue

		# Calculate Heisman score
		var score := _calculate_heisman_score(
			p,
			season_stats,
			season_records,
			college_index,
			config
		)

		candidates.append({
			"player_id": player_id,
			"position": position,
			"school_id": school_id,
			"score": score,
			"stats": season_stats
		})

	if candidates.is_empty():
		return {
			"winner": {},
			"finalists": []
		}

	# Sort by score descending
	candidates.sort_custom(func(a, b): return a["score"] > b["score"])

	# Select winner and finalists
	var winner: Dictionary = candidates[0]
	var finalists := []

	for i in range(min(finalist_count, candidates.size())):
		var finalist: Dictionary = candidates[i]
		finalists.append({
			"player_id": finalist.get("player_id", ""),
			"rank": i + 1,
			"votes": int((1.0 - float(i) / float(finalist_count + 1)) * 1000.0),  # Simulated vote count
			"school_id": finalist.get("school_id", ""),
			"position": finalist.get("position", ""),
			"score": finalist.get("score", 0.0)
		})

	return {
		"winner": {
			"player_id": winner.get("player_id", ""),
			"school_id": winner.get("school_id", ""),
			"position": winner.get("position", ""),
			"votes": 1000  # Winner gets full votes
		},
		"finalists": finalists
	}


## Selects All-American teams (1st, 2nd, 3rd team) by position.
##
## Follows the pattern of AwardSelector.select_all_pro_teams() for NFL awards.
##
## Parameters:
##   eligible_players: Array of draft-eligible players
##   career_stats: Dictionary of player career statistics
##   year: Season year
##   config: Configuration from college_awards.json
##
## Returns:
##   Dictionary with first_team, second_team, third_team arrays
##
## RNG Pattern: None (deterministic)
## Performance: O(n log n) per position group
static func select_all_americans(
	eligible_players: Array,
	career_stats: Dictionary,
	year: int,
	config: Dictionary
) -> Dictionary:
	var all_american_cfg: Dictionary = config.get("all_american", {})
	var positions_cfg: Dictionary = all_american_cfg.get("positions", {})
	var min_games_started := int(all_american_cfg.get("min_games_started", 8))

	# Group players by position
	var by_position := {}

	for player in eligible_players:
		var p: Dictionary = player
		var player_id := String(p.get("player_id", ""))
		var position := String(p.get("position", ""))

		# Get season stats
		var player_stats: Dictionary = career_stats.get(player_id, {})
		var season_stats: Dictionary = player_stats.get(year, {})

		if season_stats.is_empty():
			continue

		var games_started := int(season_stats.get("games_started", 0))
		if games_started < min_games_started:
			continue

		# Map position to All-American category
		var aa_position := _map_to_all_american_position(position)
		if aa_position == "":
			continue

		# Calculate position-specific score
		var score := _calculate_all_american_score(season_stats, position)

		if not by_position.has(aa_position):
			by_position[aa_position] = []

		(by_position[aa_position] as Array).append({
			"player_id": player_id,
			"position": aa_position,
			"original_position": position,
			"school_id": String(p.get("college_id", "")),
			"score": score
		})

	# Sort each position by score
	for pos in by_position.keys():
		var players: Array = by_position[pos]
		players.sort_custom(func(a, b): return a["score"] > b["score"])

	# Select teams
	var first_team := []
	var second_team := []
	var third_team := []

	for pos in positions_cfg.keys():
		var count := int(positions_cfg[pos])
		var players: Array = by_position.get(pos, [])

		# First team: top N
		for i in range(min(count, players.size())):
			first_team.append(players[i])

		# Second team: next N
		for i in range(count, min(count * 2, players.size())):
			second_team.append(players[i])

		# Third team: next N
		for i in range(count * 2, min(count * 3, players.size())):
			third_team.append(players[i])

	return {
		"first_team": first_team,
		"second_team": second_team,
		"third_team": third_team
	}


## Selects conference awards (Offensive POY, Defensive POY) for each conference.
##
## Parameters:
##   eligible_players: Array of draft-eligible players
##   career_stats: Dictionary of player career statistics
##   season_records: Dictionary of team season records
##   college_index: Dictionary mapping college_id to college data
##   year: Season year
##   config: Configuration from college_awards.json
##
## Returns:
##   Dictionary mapping conference_id to {offensive_poy, defensive_poy}
##
## RNG Pattern: None (deterministic)
## Performance: O(n log n) per conference
static func select_conference_awards(
	eligible_players: Array,
	career_stats: Dictionary,
	season_records: Dictionary,
	college_index: Dictionary,
	year: int,
	config: Dictionary
) -> Dictionary:
	var conf_cfg: Dictionary = config.get("conference_awards", {})
	var voting_weights: Dictionary = conf_cfg.get("voting_weights", {})

	# Group players by conference and offense/defense
	var by_conference := {}

	for player in eligible_players:
		var p: Dictionary = player
		var player_id := String(p.get("player_id", ""))
		var position := String(p.get("position", ""))
		var school_id := String(p.get("college_id", ""))

		# Get college conference
		var college: Dictionary = college_index.get(school_id, {})
		var conference_id := String(college.get("conference", ""))

		if conference_id == "":
			continue

		# Get season stats
		var player_stats: Dictionary = career_stats.get(player_id, {})
		var season_stats: Dictionary = player_stats.get(year, {})

		if season_stats.is_empty():
			continue

		# Calculate conference award score
		var score := _calculate_conference_award_score(
			season_stats,
			position,
			season_records,
			school_id,
			voting_weights
		)

		# Categorize by offense/defense
		var category := "offense" if position in OFFENSIVE_POSITIONS else "defense"

		if not by_conference.has(conference_id):
			by_conference[conference_id] = {
				"offense": [],
				"defense": []
			}

		(by_conference[conference_id][category] as Array).append({
			"player_id": player_id,
			"position": position,
			"school_id": school_id,
			"score": score
		})

	# Select winners for each conference
	var result := {}

	for conference_id in by_conference.keys():
		var conf_data: Dictionary = by_conference[conference_id]

		# Offensive POY
		var offense_candidates: Array = conf_data.get("offense", [])
		offense_candidates.sort_custom(func(a, b): return a["score"] > b["score"])

		var offensive_poy := {}
		if not offense_candidates.is_empty():
			var winner: Dictionary = offense_candidates[0]
			offensive_poy = {
				"player_id": winner.get("player_id", ""),
				"school_id": winner.get("school_id", ""),
				"position": winner.get("position", "")
			}

		# Defensive POY
		var defense_candidates: Array = conf_data.get("defense", [])
		defense_candidates.sort_custom(func(a, b): return a["score"] > b["score"])

		var defensive_poy := {}
		if not defense_candidates.is_empty():
			var winner: Dictionary = defense_candidates[0]
			defensive_poy = {
				"player_id": winner.get("player_id", ""),
				"school_id": winner.get("school_id", ""),
				"position": winner.get("position", "")
			}

		result[conference_id] = {
			"offensive_poy": offensive_poy,
			"defensive_poy": defensive_poy
		}

	return result


## Generates mock draft rankings from multiple media sources.
##
## Each source has different biases and hype susceptibility:
##   - ESPN: High hype, big school bias, entertainment-focused
##   - NFL Network: Moderate hype, balanced analysis
##   - PFF: Low hype, analytics-focused, grades over narrative
##
## Parameters:
##   draft_pool: Array of draft-eligible players
##   config: Configuration from college_awards.json
##   rng: RandomNumberGenerator for noise/variation
##
## Returns:
##   Dictionary with source_rankings and consensus
##
## RNG Pattern: randf_range() for each player per source (noise)
## Performance: O(n log n) × number of sources
static func generate_mock_draft_rankings(
	draft_pool: Array,
	config: Dictionary,
	rng: RandomNumberGenerator,
	positions_cfg: Dictionary,
	main_cfg: Dictionary
) -> Dictionary:
	var mock_cfg: Dictionary = config.get("mock_draft", {})
	var sources: Array = mock_cfg.get("sources", ["espn", "nfl_network", "pff"])
	var top_n := int(mock_cfg.get("top_n_players", 100))
	var noise_sigma := float(mock_cfg.get("noise_sigma", 15.0))
	var hype_susceptibility: Dictionary = mock_cfg.get("hype_susceptibility_by_source", {})
	var source_bias: Dictionary = mock_cfg.get("source_bias", {})

	var class_rules: Dictionary = main_cfg.get("class_rules", {})

	# Calculate base talent score for each player
	var player_scores := []
	for player in draft_pool:
		var p: Dictionary = player
		var player_id := String(p.get("player_id", ""))
		var position := String(p.get("position", ""))

		# Base talent (actual rating)
		var talent_score := PlayerRatingCalculator.calculate_overall_rating(
			p,
			positions_cfg,
			class_rules
		)

		var hype := float(p.get("hype", 50.0))
		var school_id := String(p.get("college_id", ""))

		player_scores.append({
			"player_id": player_id,
			"position": position,
			"talent_score": talent_score,
			"hype": hype,
			"school_id": school_id,
			"player_ref": p
		})

	# Generate rankings for each source
	var source_rankings := {}

	for source_name in sources:
		var susceptibility := float(hype_susceptibility.get(source_name, 0.5))
		var bias_cfg: Dictionary = source_bias.get(source_name, {})

		# Calculate source-specific scores
		var source_scores := []
		for entry in player_scores:
			var e: Dictionary = entry
			var talent := float(e["talent_score"])
			var hype := float(e["hype"])
			var position := String(e["position"])

			# Apply hype influence (normalized 0-100 → -1 to +1)
			var hype_modifier := (hype - 50.0) / 50.0  # -1.0 to +1.0
			var hype_impact := hype_modifier * susceptibility * 10.0  # ±10 points max

			# Apply position bias (flashy positions get boost from some sources)
			var position_boost := 0.0
			var flashy_positions: Array = bias_cfg.get("flashy_positions", [])
			if position in flashy_positions:
				position_boost = 3.0

			# Add Gaussian noise
			var noise := rng.randfn(0.0, noise_sigma)

			# Calculate final mock draft score
			var mock_score := talent + hype_impact + position_boost + noise

			source_scores.append({
				"player_id": e["player_id"],
				"position": position,
				"school_id": e["school_id"],
				"mock_score": mock_score,
				"talent_score": talent
			})

		# Sort by mock score and assign ranks
		source_scores.sort_custom(func(a, b): return a["mock_score"] > b["mock_score"])

		var rankings := []
		for i in range(min(top_n, source_scores.size())):
			var entry: Dictionary = source_scores[i]
			rankings.append({
				"player_id": entry["player_id"],
				"rank": i + 1,
				"position": entry["position"],
				"school_id": entry["school_id"]
			})

		source_rankings[source_name] = rankings

	# Calculate consensus rankings (average rank across sources)
	var consensus := _calculate_consensus_rankings(source_rankings, top_n)

	return {
		"source_rankings": source_rankings,
		"consensus": consensus
	}


## Calculates hype vs talent gap for a player.
##
## Positive gap = Overhyped (mock rank better than talent)
## Negative gap = Underhyped (mock rank worse than talent)
##
## Parameters:
##   player: Player dictionary
##   mock_rankings: Dictionary from generate_mock_draft_rankings()
##   positions_cfg: Position configuration
##   main_cfg: Main configuration
##
## Returns:
##   float: Gap value (-1.0 to +1.0, normalized)
##
## RNG Pattern: None (pure calculation)
static func calculate_hype_vs_talent_gap(
	player: Dictionary,
	mock_rankings: Dictionary,
	positions_cfg: Dictionary,
	main_cfg: Dictionary
) -> float:
	var player_id := String(player.get("player_id", ""))
	var consensus: Array = mock_rankings.get("consensus", [])

	if consensus.is_empty():
		return 0.0

	# Find player in consensus rankings
	var mock_rank := -1
	for i in range(consensus.size()):
		var entry: Dictionary = consensus[i]
		if String(entry.get("player_id", "")) == player_id:
			mock_rank = i + 1
			break

	if mock_rank == -1:
		return 0.0  # Not in mock drafts

	# Calculate actual talent rank
	var class_rules: Dictionary = main_cfg.get("class_rules", {})
	var talent_rating := PlayerRatingCalculator.calculate_overall_rating(
		player,
		positions_cfg,
		class_rules
	)

	# Estimate talent rank (assume normal distribution around rating)
	# Rating 90+ = top 10, Rating 80-90 = top 30, etc.
	var talent_rank := _estimate_talent_rank_from_rating(talent_rating)

	# Calculate gap (normalized)
	# If mock_rank < talent_rank, player is overhyped (positive gap)
	# If mock_rank > talent_rank, player is underhyped (negative gap)
	var raw_gap := float(talent_rank - mock_rank)
	var normalized_gap := clamp(raw_gap / 50.0, -1.0, 1.0)

	return normalized_gap


## PRIVATE HELPER FUNCTIONS


## Builds a mapping from college_id to college data.
static func _build_college_index(colleges: Array) -> Dictionary:
	var index := {}
	for college in colleges:
		var c: Dictionary = college
		var college_id := String(c.get("id", ""))
		if college_id != "":
			index[college_id] = c
	return index


## Calculates Heisman Trophy score for a player.
##
## Scoring factors:
##   - Stats production (40%)
##   - Efficiency metrics (25%)
##   - Team success (20%)
##   - Hype/narrative (15%)
static func _calculate_heisman_score(
	player: Dictionary,
	season_stats: Dictionary,
	season_records: Dictionary,
	college_index: Dictionary,
	config: Dictionary
) -> float:
	var heisman_cfg: Dictionary = config.get("heisman", {})
	var weights: Dictionary = heisman_cfg.get("voting_weights", {})
	var position_bias: Dictionary = heisman_cfg.get("position_bias", {})

	var position := String(player.get("position", ""))
	var school_id := String(player.get("college_id", ""))

	# 1. Stats production score
	var stats_score := _calculate_production_score(season_stats, position)

	# 2. Efficiency metrics score
	var efficiency_score := _calculate_efficiency_score(season_stats, position)

	# 3. Team success score
	var team_success_score := _calculate_team_success_score(
		school_id,
		season_records,
		college_index
	)

	# 4. Hype/narrative score
	var hype := float(player.get("hype", 50.0))
	var hype_score := (hype - 50.0) / 50.0 * 100.0  # Normalize to 0-100

	# Weighted combination
	var total_score := (
		stats_score * float(weights.get("stats_production", 0.4)) +
		efficiency_score * float(weights.get("efficiency_metrics", 0.25)) +
		team_success_score * float(weights.get("team_success", 0.2)) +
		hype_score * float(weights.get("hype", 0.15))
	)

	# Apply position bias (QBs favored)
	var bias_mult := float(position_bias.get(position, 1.0))
	total_score *= bias_mult

	return total_score


## Calculates production score based on raw stats.
static func _calculate_production_score(stats: Dictionary, position: String) -> float:
	match position:
		"QB":
			var pass_yards := float(stats.get("passing_yards", 0))
			var pass_tds := float(stats.get("touchdown_passes", 0))
			var interceptions := float(stats.get("interceptions", 0))
			return (pass_yards / 50.0) + (pass_tds * 4.0) - (interceptions * 2.0)

		"RB":
			var rush_yards := float(stats.get("rushing_yards", 0))
			var rush_tds := float(stats.get("rushing_touchdowns", 0))
			var rec_yards := float(stats.get("receiving_yards", 0))
			var rec_tds := float(stats.get("receiving_touchdowns", 0))
			return (rush_yards / 20.0) + (rush_tds * 6.0) + (rec_yards / 30.0) + (rec_tds * 6.0)

		"WR":
			var receptions := float(stats.get("receptions", 0))
			var rec_yards := float(stats.get("receiving_yards", 0))
			var rec_tds := float(stats.get("receiving_touchdowns", 0))
			return (receptions * 1.5) + (rec_yards / 20.0) + (rec_tds * 6.0)

		_:
			return 0.0


## Calculates efficiency score based on advanced metrics.
static func _calculate_efficiency_score(stats: Dictionary, position: String) -> float:
	match position:
		"QB":
			var attempts := float(stats.get("attempts", 1))
			var completions := float(stats.get("completions", 0))
			var pass_yards := float(stats.get("passing_yards", 0))
			var completion_pct := (completions / attempts) * 100.0 if attempts > 0 else 0.0
			var yards_per_attempt := pass_yards / attempts if attempts > 0 else 0.0
			return (completion_pct * 0.5) + (yards_per_attempt * 8.0)

		"RB":
			var carries := float(stats.get("carries", 1))
			var rush_yards := float(stats.get("rushing_yards", 0))
			var yards_per_carry := rush_yards / carries if carries > 0 else 0.0
			return yards_per_carry * 15.0

		"WR":
			var targets := float(stats.get("targets", 1))
			var receptions := float(stats.get("receptions", 0))
			var rec_yards := float(stats.get("receiving_yards", 0))
			var catch_rate := (receptions / targets) * 100.0 if targets > 0 else 0.0
			var yards_per_rec := rec_yards / receptions if receptions > 0 else 0.0
			return (catch_rate * 0.5) + (yards_per_rec * 3.0)

		_:
			return 0.0


## Calculates team success score (wins, conference standing).
static func _calculate_team_success_score(
	school_id: String,
	season_records: Dictionary,
	college_index: Dictionary
) -> float:
	var team_record: Dictionary = season_records.get(school_id, {})

	if team_record.is_empty():
		return 50.0  # Neutral if no record

	var wins := float(team_record.get("wins", 0))
	var losses := float(team_record.get("losses", 0))
	var total_games := wins + losses

	if total_games == 0:
		return 50.0

	var win_pct := wins / total_games

	# Bonus for championship/playoff appearance
	var is_champion := bool(team_record.get("is_champion", false))
	var playoff_appearance := bool(team_record.get("playoff_appearance", false))

	var base_score := win_pct * 100.0
	if is_champion:
		base_score += 20.0
	elif playoff_appearance:
		base_score += 10.0

	return base_score


## Calculates All-American score (similar to NFL All-Pro).
static func _calculate_all_american_score(stats: Dictionary, position: String) -> float:
	# Use same scoring as production + efficiency
	var production := _calculate_production_score(stats, position)
	var efficiency := _calculate_efficiency_score(stats, position)
	return (production * 0.6) + (efficiency * 0.4)


## Calculates conference award score.
static func _calculate_conference_award_score(
	stats: Dictionary,
	position: String,
	season_records: Dictionary,
	school_id: String,
	weights: Dictionary
) -> float:
	var production := _calculate_production_score(stats, position)
	var efficiency := _calculate_efficiency_score(stats, position)

	# Team contribution (simplified - based on games started)
	var games_started := float(stats.get("games_started", 0))
	var games_played := float(stats.get("games_played", 1))
	var contribution := (games_started / games_played) * 100.0 if games_played > 0 else 0.0

	return (
		production * float(weights.get("stats_production", 0.5)) +
		efficiency * float(weights.get("efficiency_metrics", 0.3)) +
		contribution * float(weights.get("team_contribution", 0.2))
	)


## Maps specific positions to All-American categories.
static func _map_to_all_american_position(position: String) -> String:
	match position:
		"QB": return "QB"
		"RB": return "RB"
		"WR": return "WR"
		"TE": return "TE"
		"OL", "OT", "OG", "C": return "OL"
		"DL", "DT": return "DL"
		"DE", "EDGE": return "EDGE"
		"LB": return "LB"
		"CB": return "CB"
		"S": return "S"
		_: return ""


## Calculates consensus rankings from multiple sources.
static func _calculate_consensus_rankings(source_rankings: Dictionary, top_n: int) -> Array:
	# Collect all player ranks from all sources
	var player_ranks := {}

	for source_name in source_rankings.keys():
		var rankings: Array = source_rankings[source_name]
		for entry in rankings:
			var e: Dictionary = entry
			var player_id := String(e.get("player_id", ""))
			var rank := int(e.get("rank", 0))

			if not player_ranks.has(player_id):
				player_ranks[player_id] = {
					"player_id": player_id,
					"position": e.get("position", ""),
					"school_id": e.get("school_id", ""),
					"ranks": [],
					"appearances": 0
				}

			(player_ranks[player_id]["ranks"] as Array).append(rank)
			player_ranks[player_id]["appearances"] = int(player_ranks[player_id]["appearances"]) + 1

	# Calculate average rank for each player
	var consensus_list := []
	for player_id in player_ranks.keys():
		var data: Dictionary = player_ranks[player_id]
		var ranks: Array = data["ranks"]
		var appearances := int(data["appearances"])

		# Calculate average rank
		var sum := 0.0
		for rank in ranks:
			sum += float(rank)
		var avg_rank := sum / float(ranks.size())

		# Calculate variance
		var variance := 0.0
		for rank in ranks:
			var diff := float(rank) - avg_rank
			variance += diff * diff
		variance /= float(ranks.size())

		# Penalize players who don't appear in all sources
		# (assume they'd be ranked lower by missing sources)
		var source_count := source_rankings.size()
		if appearances < source_count:
			avg_rank += float(source_count - appearances) * 20.0

		consensus_list.append({
			"player_id": player_id,
			"position": data["position"],
			"school_id": data["school_id"],
			"avg_rank": avg_rank,
			"rank_variance": variance,
			"sources_count": appearances
		})

	# Sort by average rank
	consensus_list.sort_custom(func(a, b): return a["avg_rank"] < b["avg_rank"])

	# Return top N
	var result := []
	for i in range(min(top_n, consensus_list.size())):
		var entry: Dictionary = consensus_list[i]
		result.append({
			"player_id": entry["player_id"],
			"rank": i + 1,
			"avg_rank": entry["avg_rank"],
			"rank_variance": entry["rank_variance"],
			"position": entry["position"],
			"school_id": entry["school_id"]
		})

	return result


## Estimates talent rank from overall rating.
static func _estimate_talent_rank_from_rating(rating: float) -> int:
	# Approximate mapping: rating → rank
	if rating >= 95.0:
		return 1  # Elite, top pick
	elif rating >= 90.0:
		return int(2 + (95.0 - rating) * 2.0)  # Top 10
	elif rating >= 85.0:
		return int(10 + (90.0 - rating) * 4.0)  # Top 30
	elif rating >= 80.0:
		return int(30 + (85.0 - rating) * 6.0)  # Top 60
	elif rating >= 75.0:
		return int(60 + (80.0 - rating) * 8.0)  # Top 100
	else:
		return int(100 + (75.0 - rating) * 5.0)  # Below top 100


## Updates player award references after award selection.
static func _update_player_award_references(
	world_state: Dictionary,
	year: int,
	heisman: Dictionary,
	all_americans: Dictionary,
	conference_awards: Dictionary
) -> void:
	var draft_pool: Dictionary = world_state.get("draft_pool", {})
	var eligible_players: Array = draft_pool.get(year, [])

	# Create lookup for fast player finding
	var player_lookup := {}
	for player in eligible_players:
		var p: Dictionary = player
		var player_id := String(p.get("player_id", ""))
		player_lookup[player_id] = p

	# Update Heisman winner - dual hype: permanent legacy + temporary draft buzz
	var winner_id := String(heisman.get("winner", {}).get("player_id", ""))
	var winner: Dictionary = player_lookup.get(winner_id, {})
	if not winner.is_empty():
		# Permanent legacy boost - you're always "Heisman winner"
		_add_to_player_history(winner, year, "award", "Heisman Trophy", "Won the Heisman Trophy", 8.0, 0.0)
		# Temporary draft buzz - massive but fades if not drafted soon
		_add_to_player_history(winner, year, "award", "Heisman Draft Buzz", "Heisman winner media frenzy", 25.0, 1.5)

	# Update Heisman finalists
	var finalists: Array = heisman.get("finalists", [])
	for finalist in finalists:
		var f: Dictionary = finalist
		var player_id := String(f.get("player_id", ""))
		var player: Dictionary = player_lookup.get(player_id, {})

		if player.is_empty():
			continue

		if not player.has("awards"):
			player["awards"] = {"college": {}}
		var college_awards: Dictionary = player["awards"].get("college", {})

		if not college_awards.has("heisman_finalist"):
			college_awards["heisman_finalist"] = []
		(college_awards["heisman_finalist"] as Array).append(year)

		player["awards"]["college"] = college_awards

		# Add to history (finalists who didn't win) - dual hype like winner but smaller
		if player_id != winner_id:
			# Permanent recognition as finalist
			_add_to_player_history(player, year, "award", "Heisman Finalist", "Named Heisman Trophy finalist", 5.0, 0.0)
			# Temporary draft buzz from finalist status
			_add_to_player_history(player, year, "award", "Heisman Finalist Buzz", "Heisman finalist media attention", 12.0, 1.5)

	# Update All-Americans - 1st team gets dual hype, others get single
	# Permanent legacy component
	var aa_legacy_hype := {"first_team": 6.0, "second_team": 4.0, "third_team": 2.0}
	# Temporary draft buzz component (only 1st team gets significant buzz)
	var aa_buzz_hype := {"first_team": 10.0, "second_team": 0.0, "third_team": 0.0}
	var aa_buzz_halflife := {"first_team": 1.5, "second_team": 0.0, "third_team": 0.0}
	for team_name in ["first_team", "second_team", "third_team"]:
		var team: Array = all_americans.get(team_name, [])
		var team_label := team_name.replace("_", " ").capitalize()
		var legacy_boost := float(aa_legacy_hype.get(team_name, 2.0))
		var buzz_boost := float(aa_buzz_hype.get(team_name, 0.0))
		var buzz_halflife := float(aa_buzz_halflife.get(team_name, 0.0))

		for member in team:
			var m: Dictionary = member
			var player_id := String(m.get("player_id", ""))
			var player: Dictionary = player_lookup.get(player_id, {})

			if player.is_empty():
				continue

			if not player.has("awards"):
				player["awards"] = {"college": {}}
			var college_awards: Dictionary = player["awards"].get("college", {})

			if not college_awards.has("all_american"):
				college_awards["all_american"] = {}
			var aa_dict: Dictionary = college_awards["all_american"]
			aa_dict[year] = team_name.replace("_team", "")

			college_awards["all_american"] = aa_dict
			player["awards"]["college"] = college_awards

			# Add permanent legacy to history
			_add_to_player_history(player, year, "award", "All-American " + team_label, "Named to All-American " + team_label, legacy_boost, 0.0)
			# Add temporary draft buzz for 1st team only
			if buzz_boost > 0.0:
				_add_to_player_history(player, year, "award", "All-American Draft Buzz", "1st Team All-American media attention", buzz_boost, buzz_halflife)

	# Update conference award winners
	for conference_id in conference_awards.keys():
		var conf_awards: Dictionary = conference_awards[conference_id]

		for award_type in ["offensive_poy", "defensive_poy"]:
			var award_winner: Dictionary = conf_awards.get(award_type, {})
			var player_id := String(award_winner.get("player_id", ""))
			var player: Dictionary = player_lookup.get(player_id, {})

			if player.is_empty():
				continue

			if not player.has("awards"):
				player["awards"] = {"college": {}}
			var college_awards: Dictionary = player["awards"].get("college", {})

			if not college_awards.has("conference_awards"):
				college_awards["conference_awards"] = {}
			var conf_awards_dict: Dictionary = college_awards["conference_awards"]

			if not conf_awards_dict.has(year):
				conf_awards_dict[year] = []
			(conf_awards_dict[year] as Array).append(award_type)

			college_awards["conference_awards"] = conf_awards_dict
			player["awards"]["college"] = college_awards

			# Add to history - conference awards have moderate staying power
			var award_label := "Offensive POY" if award_type == "offensive_poy" else "Defensive POY"
			_add_to_player_history(player, year, "award", conference_id + " " + award_label, "Named " + conference_id + " " + award_label, 6.0, 3.0)


## Adds an event to player's history and applies hype modifier.
##
## Creates a unified history entry and applies a hype modifier with optional decay.
## History entries are used for player career tracking and UI display.
##
## @param player: Player dictionary to modify
## @param year: Year the event occurred
## @param event_type: Type of event ("award", "discipline", "milestone", etc.)
## @param event_name: Short name of the event
## @param description: Human-readable description
## @param hype_impact: Immediate hype change (positive for awards, negative for discipline)
## @param halflife_years: Years for modifier to decay to half strength (0 = permanent)
static func _add_to_player_history(
	player: Dictionary,
	year: int,
	event_type: String,
	event_name: String,
	description: String,
	hype_impact: float,
	halflife_years: float = 0.0
) -> void:
	# Initialize history if not exists
	if not player.has("history"):
		player["history"] = []

	# Add to history
	var history: Array = player["history"]
	var entry := {
		"type": event_type,
		"year": year,
		"event": event_name,
		"description": description,
		"hype_impact": hype_impact
	}

	# Add halflife if specified (for decaying modifiers)
	if halflife_years > 0.0:
		entry["halflife_years"] = halflife_years

	history.append(entry)

	# Apply immediate hype change
	var current_hype := float(player.get("hype", 50.0))
	player["hype"] = clamp(current_hype + hype_impact, 0.0, 100.0)

	# Track decaying modifiers separately for accurate calculation
	if halflife_years > 0.0:
		if not player.has("hype_modifiers"):
			player["hype_modifiers"] = []
		var modifiers: Array = player["hype_modifiers"]
		modifiers.append({
			"source": event_name,
			"year_applied": year,
			"initial_impact": hype_impact,
			"halflife_years": halflife_years
		})
